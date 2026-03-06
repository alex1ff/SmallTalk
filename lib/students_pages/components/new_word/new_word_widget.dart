import '/auth/firebase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/widgets/index.dart' as custom_widgets;
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
      final tatoebaTranslationLanguageCode =
          _preferredTatoebaTranslationLanguageCode(context);

      await Future.wait([
        Future(() async {
          _model.worrd = await YandexCall.call(
            text: widget.word,
            lang: '$yandexSourceLanguageCode-$yandexTranslationLanguageCode',
          );

          safeSetState(() {});
        }),
        Future(() async {
          _model.ssss = await TatoebaCall.call(
            lang: widget.langCode,
            q: widget.word,
            showTransLang: tatoebaTranslationLanguageCode,
            transLang: tatoebaTranslationLanguageCode,
          );

          safeSetState(() {});
        }),
      ]);

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
        safeSetState(() {});
      }
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  YyStruct? _parsedWordResponse() {
    final jsonBody = _model.worrd?.jsonBody;
    if (jsonBody is! Map) return null;
    return YyStruct.maybeFromMap(jsonBody);
  }

  List<EntryStruct> _dictionaryEntries() {
    return _parsedWordResponse()?.def.toList() ?? const <EntryStruct>[];
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

    final conversationSentenceText = _conversationSentenceText();
    if (conversationSentenceText != null) {
      addSentence(
        SentenceStruct(
          text: conversationSentenceText,
          lang: _normalizeLanguageCode(widget.langCode),
        ),
      );
    }

    for (final sentence in _exampleSentences()) {
      addSentence(sentence);
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
          color: FlutterFlowTheme.of(context).secondaryText,
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
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Контекст',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  fontSize: 14.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (phraseContext != null) ...[
            const SizedBox(height: 10.0),
            Text('Фраза', style: labelStyle),
            const SizedBox(height: 4.0),
            Text(phraseContext, style: valueStyle),
          ],
          if (sentenceContext != null) ...[
            const SizedBox(height: 10.0),
            Text('Предложение', style: labelStyle),
            const SizedBox(height: 4.0),
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
      widget.langCode,
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

  List<SentenceStruct> _exampleSentences() {
    final jsonBody = _model.ssss?.jsonBody;
    if (jsonBody is! Map) {
      return const <SentenceStruct>[];
    }

    return DataStruct.maybeFromMap(jsonBody)?.data.toList() ??
        const <SentenceStruct>[];
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
        decoration: BoxDecoration(),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 40.0, 0.0, 0.0),
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
                        Container(
                          width: double.infinity,
                          height: 16.0,
                          child: custom_widgets.NotchedClipper(
                            width: double.infinity,
                            height: 16.0,
                          ),
                        ),
                        Flexible(
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(0.0),
                              bottomRight: Radius.circular(0.0),
                              topLeft: Radius.circular(0.0),
                              topRight: Radius.circular(0.0),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(0.0),
                                  bottomRight: Radius.circular(0.0),
                                  topLeft: Radius.circular(0.0),
                                  topRight: Radius.circular(0.0),
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
                                                    6.0, 0.0, 6.0, 0.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryBackground,
                                                borderRadius:
                                                    BorderRadius.circular(26.0),
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
                                                          if (_model.worrd !=
                                                              null) {
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
                                            opacity: _model.worrd != null
                                                ? 1.0
                                                : 0.0,
                                            duration: 200.0.ms,
                                            curve: Curves.easeInOut,
                                            child: Padding(
                                              padding: EdgeInsets.all(16.0),
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
                                                                height: 24.0),
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
                                                                                21.0,
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
                                                                            21.0,
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
                                                                            21.0,
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
                                                                            21.0,
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
                                                                                8.0),
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
                                                                                0.0,
                                                                                12.0,
                                                                                0.0,
                                                                                0.0),
                                                                            child:
                                                                                Builder(
                                                                              builder: (context) {
                                                                                final sssss = functions.syn(trItem.gen, trItem.text, trItem.syn.toList())?.toList() ?? [];

                                                                                return Wrap(
                                                                                  spacing: 4.0,
                                                                                  runSpacing: 8.0,
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
                                                                                        color: FlutterFlowTheme.of(context).primaryBackground,
                                                                                        borderRadius: BorderRadius.circular(50.0),
                                                                                      ),
                                                                                      child: Padding(
                                                                                        padding: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
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
                                                                                                          color: Colors.black,
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
                                                                                0.0,
                                                                                6.0,
                                                                                0.0,
                                                                                0.0),
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
                                                              fontSize: 21.0,
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
                                                                  height: 8.0),
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
                                                                          0.0,
                                                                          6.0,
                                                                          0.0,
                                                                          0.0),
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
                                            .addToStart(SizedBox(height: 16.0))
                                            .addToEnd(SizedBox(height: 24.0)),
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
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 6.0, 20.0),
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
                                                await containerUserWordsRecordList
                                                    .where((e) =>
                                                        e.entry.firstOrNull
                                                            ?.text ==
                                                        primaryEntryText)
                                                    .toList()
                                                    .firstOrNull!
                                                    .reference
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
                                                  color: Colors.black,
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
                                            var userWordsRecordReference =
                                                UserWordsRecord.createDoc(
                                                    currentUserReference!);
                                            await userWordsRecordReference.set({
                                              ...createUserWordsRecordData(
                                                addedAt: getCurrentTimestamp,
                                              ),
                                              ...mapToFirestore(
                                                {
                                                  'entry':
                                                      getEntryListFirestoreData(
                                                    _parsedWordResponse()?.def,
                                                  ),
                                                  'Sentence':
                                                      getSentenceListFirestoreData(
                                                    sentencesToSave,
                                                  ),
                                                },
                                              ),
                                            });
                                            _model.erweerw = UserWordsRecord
                                                .getDocumentFromData({
                                              ...createUserWordsRecordData(
                                                addedAt: getCurrentTimestamp,
                                              ),
                                              ...mapToFirestore(
                                                {
                                                  'entry':
                                                      getEntryListFirestoreData(
                                                    _parsedWordResponse()?.def,
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
                                            alignment:
                                                AlignmentDirectional(0.0, 0.0),
                                            children: [
                                              Icon(
                                                FFIcons.kstar01,
                                                color: Colors.black,
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
                            Container(
                              decoration: BoxDecoration(
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
                              child: FlutterFlowIconButton(
                                borderRadius: 50.0,
                                buttonSize: 60.0,
                                fillColor: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                icon: Icon(
                                  Icons.close_sharp,
                                  color: FlutterFlowTheme.of(context).error,
                                  size: 20.0,
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          ].divide(SizedBox(height: 6.0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ].divide(SizedBox(width: 4.0)),
          ),
        ),
      ),
    );
  }
}
