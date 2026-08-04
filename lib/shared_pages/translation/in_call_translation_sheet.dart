import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/services/translation_repository.dart';
import '/shared_pages/design/expatlio_design.dart';

class InCallTranslationSheet extends StatefulWidget {
  const InCallTranslationSheet({
    super.key,
    required this.sessionId,
    required this.practicedLanguageCode,
    this.repository = const TranslationRepository(),
  });

  final String sessionId;
  final String practicedLanguageCode;
  final TranslationRepository repository;

  @override
  State<InCallTranslationSheet> createState() => _InCallTranslationSheetState();
}

class _InCallTranslationSheetState extends State<InCallTranslationSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  TranslationLanguage _sourceLanguage = TranslationLanguage.russian;
  TranslationResult? _result;
  TranslationFailure? _failure;
  bool _isTranslating = false;
  bool _isSaving = false;
  bool _saved = false;

  TranslationLanguage get _targetLanguage =>
      _sourceLanguage == TranslationLanguage.russian
          ? TranslationLanguage.english
          : TranslationLanguage.russian;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.text.isNotEmpty || _result != null) return;
    final practiced = widget.practicedLanguageCode.trim().toLowerCase();
    if (practiced.startsWith('en')) {
      _sourceLanguage = TranslationLanguage.russian;
    } else if (practiced.startsWith('ru')) {
      _sourceLanguage = TranslationLanguage.english;
    } else {
      _sourceLanguage = Localizations.localeOf(context).languageCode == 'ru'
          ? TranslationLanguage.russian
          : TranslationLanguage.english;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _languageName(TranslationLanguage language) {
    switch (language) {
      case TranslationLanguage.russian:
        return 'Русский';
      case TranslationLanguage.english:
        return 'English';
    }
  }

  void _swapLanguages() {
    if (_isTranslating) return;
    setState(() {
      _sourceLanguage = _targetLanguage;
      _result = null;
      _failure = null;
      _saved = false;
    });
  }

  Future<void> _translate() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTranslating) return;
    setState(() {
      _isTranslating = true;
      _result = null;
      _failure = null;
      _saved = false;
    });
    try {
      final result = await widget.repository.translate(
        sessionId: widget.sessionId,
        text: text,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on TranslationFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } on FormatException {
      if (!mounted) return;
      setState(() => _failure = const TranslationFailure(
            code: 'invalid_server_response',
          ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _failure = const TranslationFailure(
            code: 'unexpected_error',
          ));
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _copyResult() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.translatedText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(FFLocalizations.of(context).getVariableText(
          ruText: 'Перевод скопирован',
          enText: 'Translation copied',
        )),
      ),
    );
  }

  Future<void> _saveResult() async {
    final result = _result;
    if (result == null || _isSaving || _saved) return;
    setState(() => _isSaving = true);
    try {
      await widget.repository.saveToDictionary(lookupId: result.lookupId);
      if (!mounted) return;
      setState(() => _saved = true);
    } on TranslationFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(failure))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FFLocalizations.of(context).getVariableText(
            ruText: 'Не удалось сохранить слово. Попробуйте ещё раз.',
            enText: 'Could not save the word. Please try again.',
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _errorMessage(TranslationFailure failure) {
    switch (failure.code) {
      case 'translation_daily_limit':
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Лимит переводов на сегодня исчерпан.',
          enText: 'Today’s translation limit has been reached.',
        );
      case 'session_not_active':
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Перевод доступен только во время активного звонка.',
          enText: 'Translation is available only during an active call.',
        );
      case 'app_check_required':
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Не удалось подтвердить приложение. Перезапустите его.',
          enText: 'The app could not be verified. Please restart it.',
        );
      case 'translation_pending':
      case 'translation_retry_later':
      case 'translation_cooldown':
        return FFLocalizations.of(context).getVariableText(
          ruText:
              'Перевод уже обрабатывается. Повторите через несколько секунд.',
          enText: 'Translation is already processing. Retry in a few seconds.',
        );
      case 'feature_disabled':
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Перевод временно недоступен.',
          enText: 'Translation is temporarily unavailable.',
        );
      default:
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Не удалось перевести. Проверьте интернет и повторите.',
          enText: 'Could not translate. Check your connection and retry.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTranslate = _controller.text.trim().isNotEmpty && !_isTranslating;
    final result = _result;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: ExpatlioDesign.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              ExpatlioDesign.space24,
              ExpatlioDesign.space12,
              ExpatlioDesign.space24,
              ExpatlioDesign.space24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space16),
                Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Быстрый перевод',
                    enText: 'Quick translation',
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: ExpatlioDesign.text,
                      ),
                ),
                const SizedBox(height: ExpatlioDesign.space12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_languageName(_sourceLanguage)} → '
                        '${_languageName(_targetLanguage)}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isTranslating ? null : _swapLanguages,
                      tooltip: FFLocalizations.of(context).getVariableText(
                        ruText: 'Поменять языки',
                        enText: 'Swap languages',
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: ExpatlioDesign.space8),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 250,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {
                    _result = null;
                    _failure = null;
                    _saved = false;
                  }),
                  onSubmitted: (_) => _translate(),
                  decoration: InputDecoration(
                    hintText: FFLocalizations.of(context).getVariableText(
                      ruText: 'Введите слово или фразу',
                      enText: 'Enter a word or phrase',
                    ),
                    filled: true,
                    fillColor: ExpatlioDesign.card,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusMedium),
                      borderSide:
                          const BorderSide(color: ExpatlioDesign.border),
                    ),
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space8),
                FilledButton.icon(
                  onPressed: canTranslate ? _translate : null,
                  icon: _isTranslating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate_rounded),
                  label: Text(FFLocalizations.of(context).getVariableText(
                    ruText: _isTranslating ? 'Переводим…' : 'Перевести',
                    enText: _isTranslating ? 'Translating…' : 'Translate',
                  )),
                ),
                if (_failure != null) ...[
                  const SizedBox(height: ExpatlioDesign.space12),
                  Text(
                    _errorMessage(_failure!),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (result != null) ...[
                  const SizedBox(height: ExpatlioDesign.space16),
                  Container(
                    padding: const EdgeInsets.all(ExpatlioDesign.space16),
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.card,
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusMedium),
                      border: Border.all(color: ExpatlioDesign.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          result.translatedText,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: ExpatlioDesign.space12),
                        Wrap(
                          spacing: ExpatlioDesign.space8,
                          runSpacing: ExpatlioDesign.space8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _copyResult,
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: 'Копировать',
                                  enText: 'Copy',
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  _isSaving || _saved ? null : _saveResult,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _saved
                                          ? Icons.check_rounded
                                          : Icons.bookmark_add_outlined,
                                      size: 18,
                                    ),
                              label: Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: _saved ? 'Сохранено' : 'В словарь',
                                  enText: _saved ? 'Saved' : 'Save',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
