import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/components/word_detail_content.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';

class WordSheetContent extends StatelessWidget {
  const WordSheetContent({
    super.key,
    required this.content,
    required this.isLookupLoading,
    required this.isSaved,
    required this.isTogglingSaved,
    required this.canManageDictionary,
    required this.onToggleSaved,
    this.saveError,
    this.phraseContext,
    this.sentenceContext,
  });

  final WordDetailContent content;
  final bool isLookupLoading;
  final bool isSaved;
  final bool isTogglingSaved;
  final bool canManageDictionary;
  final Future<void> Function() onToggleSaved;
  final String? saveError;
  final String? phraseContext;
  final String? sentenceContext;

  @override
  Widget build(BuildContext context) {
    final hasTranslation = content.translationText != '-';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ExpatlioDesign.space20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _WordHeading(
            content: content,
            isSaved: isSaved,
            isBusy: isTogglingSaved,
            canManageDictionary: canManageDictionary,
            onToggleSaved: onToggleSaved,
          ),
          if (saveError != null) ...[
            const SizedBox(height: ExpatlioDesign.space8),
            Text(
              saveError!,
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.danger,
                size: 13,
                weight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: ExpatlioDesign.space20),
          if (isLookupLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(ExpatlioDesign.space16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (hasTranslation)
            _TranslationCard(content: content),
          if (_hasText(phraseContext) || _hasText(sentenceContext)) ...[
            const SizedBox(height: ExpatlioDesign.space16),
            _ContextCard(
              phrase: phraseContext,
              sentence: sentenceContext,
            ),
          ],
          if (content.examples.isNotEmpty) ...[
            const SizedBox(height: ExpatlioDesign.space24),
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Примеры',
                enText: 'Examples',
              ),
              style: ExpatlioDesign.textStyle(
                context,
                size: 20,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space12),
            ...content.examples.map(
              (sentence) => Padding(
                padding: const EdgeInsets.only(
                  bottom: ExpatlioDesign.space12,
                ),
                child: _ExampleCard(sentence: sentence),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static bool _hasText(String? value) => value?.trim().isNotEmpty ?? false;
}

class _WordHeading extends StatelessWidget {
  const _WordHeading({
    required this.content,
    required this.isSaved,
    required this.isBusy,
    required this.canManageDictionary,
    required this.onToggleSaved,
  });

  final WordDetailContent content;
  final bool isSaved;
  final bool isBusy;
  final bool canManageDictionary;
  final Future<void> Function() onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final localizations = FFLocalizations.of(context);
    final label = isSaved
        ? localizations.getVariableText(
            ruText: 'Удалить из словаря',
            enText: 'Remove from dictionary',
          )
        : localizations.getVariableText(
            ruText: 'Добавить в словарь',
            enText: 'Add to dictionary',
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                content.sourceText,
                style: ExpatlioDesign.textStyle(
                  context,
                  size: 32,
                  weight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              if (content.transcription.isNotEmpty) ...[
                const SizedBox(height: ExpatlioDesign.space8),
                Text(
                  content.transcription,
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: ExpatlioDesign.muted,
                    size: 17,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (canManageDictionary) ...[
          const SizedBox(width: ExpatlioDesign.space12),
          Semantics(
            button: true,
            enabled: !isBusy,
            label: label,
            child: IconButton(
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              tooltip: label,
              onPressed: isBusy ? null : () => onToggleSaved(),
              icon: isBusy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isSaved ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isSaved
                          ? ExpatlioDesign.primary
                          : ExpatlioDesign.text,
                      size: 30,
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TranslationCard extends StatelessWidget {
  const _TranslationCard({required this.content});

  final WordDetailContent content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ExpatlioDesign.space16),
      decoration: ExpatlioDesign.cardDecoration(
        radius: ExpatlioDesign.radiusLarge,
        borderColor: ExpatlioDesign.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Перевод',
              enText: 'Translation',
            ),
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.muted,
              size: 13,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ExpatlioDesign.space8),
          Text(
            content.translationText,
            style: ExpatlioDesign.textStyle(
              context,
              size: 23,
              weight: FontWeight.w700,
            ),
          ),
          if (content.additionalTranslations.isNotEmpty) ...[
            const SizedBox(height: ExpatlioDesign.space16),
            _ValueWrap(values: content.additionalTranslations),
          ],
          if (content.meanings.isNotEmpty) ...[
            const SizedBox(height: ExpatlioDesign.space12),
            Text(
              content.meanings.join(' · '),
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 14,
                weight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
          if (content.translationSynonyms.isNotEmpty) ...[
            const SizedBox(height: ExpatlioDesign.space12),
            _ValueWrap(values: content.translationSynonyms),
          ],
        ],
      ),
    );
  }
}

class _ValueWrap extends StatelessWidget {
  const _ValueWrap({required this.values});

  final List<SynonymStruct> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ExpatlioDesign.space8,
      runSpacing: ExpatlioDesign.space8,
      children: values
          .map(
            (value) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ExpatlioDesign.space12,
                vertical: ExpatlioDesign.space8,
              ),
              decoration: BoxDecoration(
                color: ExpatlioDesign.mutedSurface,
                borderRadius: BorderRadius.circular(
                  ExpatlioDesign.radiusCapsule,
                ),
              ),
              child: Text(
                value.text,
                style: ExpatlioDesign.textStyle(
                  context,
                  size: 14,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({this.phrase, this.sentence});

  final String? phrase;
  final String? sentence;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ExpatlioDesign.space16),
      decoration: ExpatlioDesign.cardDecoration(
        radius: ExpatlioDesign.radiusLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Контекст',
              enText: 'Context',
            ),
            style: ExpatlioDesign.textStyle(
              context,
              size: 17,
              weight: FontWeight.w700,
            ),
          ),
          if (phrase?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: ExpatlioDesign.space12),
            Text(
              phrase!.trim(),
              style: ExpatlioDesign.textStyle(
                context,
                size: 16,
                weight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
          if (sentence?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: ExpatlioDesign.space8),
            Text(
              sentence!.trim(),
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 15,
                weight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.sentence});

  final SentenceStruct sentence;

  @override
  Widget build(BuildContext context) {
    final translation = sentence.translations.firstOrNull?.text.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ExpatlioDesign.space16),
      decoration: ExpatlioDesign.cardDecoration(
        radius: ExpatlioDesign.radiusLarge,
        borderColor: ExpatlioDesign.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            sentence.text,
            style: ExpatlioDesign.textStyle(
              context,
              size: 16,
              weight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          if (translation.isNotEmpty) ...[
            const SizedBox(height: ExpatlioDesign.space8),
            Text(
              translation,
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 15,
                weight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
