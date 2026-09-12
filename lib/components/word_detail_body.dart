import '/backend/backend.dart';
import '/components/word_detail_content.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class WordDetailBody extends StatelessWidget {
  const WordDetailBody({
    super.key,
    required this.content,
  });

  final WordDetailContent content;

  @override
  Widget build(BuildContext context) {
    final examples = content.examples;
    final sourceSynonyms = content.sourceSynonyms;

    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space20,
          ExpatlioDesign.space32,
          ExpatlioDesign.space20,
          ExpatlioDesign.space40 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.sourceText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              size: 36.0,
              weight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          if (content.transcription.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0),
              child: Text(
                content.transcription,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.muted,
                  size: 20.0,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          if (sourceSynonyms.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0),
              child: _SynonymWrap(synonyms: sourceSynonyms),
            ),
          const SizedBox(height: ExpatlioDesign.space32),
          _InfoCard(
            label: FFLocalizations.of(context).getVariableText(
              ruText: 'ПЕРЕВОД',
              enText: 'TRANSLATION',
            ),
            child: _TranslationDetails(content: content),
          ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: ExpatlioDesign.space32),
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'ПРИМЕРЫ',
                enText: 'EXAMPLES',
              ),
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 16.0,
                weight: FontWeight.w500,
                height: 1.2,
              ).copyWith(letterSpacing: 1.2),
            ),
            const SizedBox(height: ExpatlioDesign.space20),
            ...examples.map(
              (example) => Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space16),
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
          style: ExpatlioDesign.textStyle(
            context,
            size: 22.0,
            weight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: ExpatlioDesign.space20),
          ...groups.map(
            (group) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space16),
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
              ExpatlioDesign.space0,
              hasSynonyms ? ExpatlioDesign.space8 : ExpatlioDesign.space0,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0,
            ),
            child: Text(
              meaningsText,
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 15.0,
                weight: FontWeight.w500,
                height: 1.25,
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
      spacing: ExpatlioDesign.space8,
      runSpacing: ExpatlioDesign.space8,
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
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(ExpatlioDesign.space12,
          ExpatlioDesign.space8, ExpatlioDesign.space12, ExpatlioDesign.space8),
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
          style: ExpatlioDesign.textStyle(
            context,
            size: 15.0,
            weight: FontWeight.w500,
          ),
        ),
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
        borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
        border: Border.all(color: ExpatlioDesign.border),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space20,
          ExpatlioDesign.space20,
          ExpatlioDesign.space20,
          ExpatlioDesign.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.muted,
              size: 14.0,
              weight: FontWeight.w500,
              height: 1.2,
            ).copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: ExpatlioDesign.space20),
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
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        border: Border.all(color: ExpatlioDesign.border),
      ),
      padding: const EdgeInsetsDirectional.all(ExpatlioDesign.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sentence.text,
            style: ExpatlioDesign.textStyle(
              context,
              size: 18.0,
              weight: FontWeight.w500,
              height: 1.25,
            ),
          ),
          if (_translation.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0),
              child: Text(
                _translation,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.muted,
                  size: 17.0,
                  weight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
