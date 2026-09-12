import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/translation_repository.dart';
import '/services/error_reporting/error_reporter.dart';
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
  TranslationLanguage _fallbackSourceLanguage = TranslationLanguage.russian;
  TranslationResult? _result;
  TranslationFailure? _failure;
  bool _isTranslating = false;
  bool _isSaving = false;
  bool _saved = false;
  int _translationGeneration = 0;

  TranslationLanguage get _sourceLanguage => detectTranslationSourceLanguage(
        _controller.text,
        fallback: _fallbackSourceLanguage,
      );

  TranslationLanguage get _targetLanguage =>
      oppositeTranslationLanguage(_sourceLanguage);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.text.isNotEmpty || _result != null) return;
    _fallbackSourceLanguage = resolveTranslationFallbackLanguage(
      practicedLanguageCode: widget.practicedLanguageCode,
      appLocaleLanguageCode: Localizations.localeOf(context).languageCode,
    );
  }

  @override
  void dispose() {
    _translationGeneration += 1;
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

  Future<void> _translate() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTranslating) return;
    final sourceLanguage = detectTranslationSourceLanguage(
      text,
      fallback: _fallbackSourceLanguage,
    );
    final targetLanguage = oppositeTranslationLanguage(sourceLanguage);
    final generation = ++_translationGeneration;
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
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      if (!mounted ||
          generation != _translationGeneration ||
          _controller.text.trim() != text) {
        return;
      }
      setState(() => _result = result);
    } on TranslationFailure catch (failure) {
      if (!mounted || generation != _translationGeneration) return;
      setState(() => _failure = failure);
    } on FormatException catch (error, st) {
      if (!mounted || generation != _translationGeneration) return;
      ErrorReporting.reporter.captureNonFatal(
        feature: ErrorFeature.translation,
        code: AppErrorCode.translationInvalidResponse,
        error: error,
        stackTrace: st,
        sessionId: widget.sessionId,
      );
      setState(() => _failure = const TranslationFailure(
            code: 'invalid_server_response',
          ));
    } catch (error, st) {
      if (!mounted || generation != _translationGeneration) return;
      ErrorReporting.reporter.captureNonFatal(
        feature: ErrorFeature.translation,
        code: AppErrorCode.translationUnexpected,
        error: error,
        stackTrace: st,
        sessionId: widget.sessionId,
      );
      setState(() => _failure = const TranslationFailure(
            code: 'unexpected_error',
          ));
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  void _handleTextChanged(String _) {
    _translationGeneration += 1;
    setState(() {
      _result = null;
      _failure = null;
      _saved = false;
    });
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
    final code = classifyCallIntegrationFailure(
      failure.code,
      isAuthenticated: currentUserUid.trim().isNotEmpty,
    );
    switch (code) {
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
      case 'auth_required':
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Войдите в аккаунт и повторите.',
          enText: 'Sign in and try again.',
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
                const SizedBox(height: ExpatlioDesign.space12),
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
                const SizedBox(height: ExpatlioDesign.space8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_languageName(_sourceLanguage)} → '
                        '${_languageName(_targetLanguage)} · '
                        '${FFLocalizations.of(context).getVariableText(ruText: 'авто', enText: 'auto')}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: ExpatlioDesign.muted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ExpatlioDesign.space8),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 250,
                  textInputAction: TextInputAction.done,
                  onChanged: _handleTextChanged,
                  onSubmitted: (_) => _focusNode.unfocus(),
                  decoration: InputDecoration(
                    hintText: FFLocalizations.of(context).getVariableText(
                      ruText: 'Введите слово или фразу',
                      enText: 'Enter a word or phrase',
                    ),
                    filled: true,
                    fillColor: ExpatlioDesign.card,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: ExpatlioDesign.space16,
                      vertical: ExpatlioDesign.space12,
                    ),
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
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: ExpatlioDesign.space16,
                      vertical: ExpatlioDesign.space12,
                    ),
                  ),
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
                  const SizedBox(height: ExpatlioDesign.space12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ExpatlioDesign.space16,
                      vertical: ExpatlioDesign.space12,
                    ),
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.card,
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusMedium),
                      border: Border.all(color: ExpatlioDesign.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SelectableText(
                            result.translatedText,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: ExpatlioDesign.space8),
                        TextButton.icon(
                          onPressed: _isSaving || _saved ? null : _saveResult,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: ExpatlioDesign.space12,
                              vertical: ExpatlioDesign.space8,
                            ),
                          ),
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
