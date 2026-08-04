import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/call_feedback_repository.dart';
import '/shared_pages/design/expatlio_design.dart';

class CallFeedbackCard extends StatefulWidget {
  const CallFeedbackCard({
    super.key,
    required this.sessionRef,
    this.repository = const CallFeedbackRepository(),
  });

  final DocumentReference sessionRef;
  final CallFeedbackRepository repository;

  @override
  State<CallFeedbackCard> createState() => _CallFeedbackCardState();
}

class _CallFeedbackCardState extends State<CallFeedbackCard> {
  StreamSubscription<CallFeedbackResponse?>? _subscription;
  Timer? _retryTimer;
  CallFeedbackResponse? _response;
  String? _unavailableCode;
  String? _activeScope;
  String _outputLocale = 'ru';
  bool _initialInvocationStarted = false;
  bool _callInFlight = false;
  int _scopeGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale =
        Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'ru';
    final scope = '${widget.sessionRef.path}|$currentUserUid|$locale';
    if (_activeScope != scope) {
      _outputLocale = locale;
      _resetScope(scope);
    }
  }

  @override
  void didUpdateWidget(covariant CallFeedbackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionRef.path != widget.sessionRef.path) {
      _activeScope = null;
      didChangeDependencies();
    }
  }

  @override
  void dispose() {
    _scopeGeneration += 1;
    _retryTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  void _resetScope(String scope) {
    _scopeGeneration += 1;
    final generation = _scopeGeneration;
    _retryTimer?.cancel();
    unawaited(_subscription?.cancel());
    _activeScope = scope;
    _response = null;
    _unavailableCode = null;
    _initialInvocationStarted = false;
    _callInFlight = false;

    final userId = currentUserUid.trim();
    if (userId.isEmpty) {
      _unavailableCode = 'auth_required';
      return;
    }
    _subscription = widget.repository
        .watch(sessionRef: widget.sessionRef, userId: userId)
        .listen(
      (response) {
        if (!mounted || generation != _scopeGeneration) return;
        if (response == null) {
          if (!_initialInvocationStarted) {
            _initialInvocationStarted = true;
            unawaited(_invoke(generation));
          }
          return;
        }
        _applyResponse(response, generation);
      },
      onError: (_) {
        if (!mounted || generation != _scopeGeneration) return;
        setState(() => _unavailableCode = 'feedback_read_failed');
      },
    );
  }

  Future<void> _invoke(int generation) async {
    if (_callInFlight || generation != _scopeGeneration) return;
    _retryTimer?.cancel();
    _callInFlight = true;
    if (mounted) setState(() => _unavailableCode = null);
    try {
      final response = await widget.repository.generate(
        sessionId: widget.sessionRef.id,
        outputLocale: _outputLocale,
      );
      if (!mounted || generation != _scopeGeneration) return;
      _applyResponse(response, generation);
    } on CallFeedbackFailure catch (failure) {
      if (!mounted || generation != _scopeGeneration) return;
      setState(() {
        if (failure.isRetryable) {
          _response = CallFeedbackResponse(
            status: CallFeedbackStatus.retryableFailure,
            retryAfterMs: failure.retryAfterMs,
            errorCode: failure.code,
          );
        } else {
          _unavailableCode = failure.code;
        }
      });
    } on FormatException {
      if (!mounted || generation != _scopeGeneration) return;
      setState(() => _unavailableCode = 'invalid_server_response');
    } catch (_) {
      if (!mounted || generation != _scopeGeneration) return;
      setState(() => _unavailableCode = 'unexpected_error');
    } finally {
      if (generation == _scopeGeneration) _callInFlight = false;
    }
  }

  void _applyResponse(CallFeedbackResponse response, int generation) {
    if (!mounted || generation != _scopeGeneration) return;
    if (response.isFinal) _retryTimer?.cancel();
    setState(() {
      _response = response;
      _unavailableCode = null;
    });
    if (response.status == CallFeedbackStatus.pending) {
      _scheduleRetry(response.retryAfterMs ?? 15000, generation);
    }
  }

  void _scheduleRetry(int delayMs, int generation) {
    _retryTimer?.cancel();
    final safeDelayMs = delayMs.clamp(1000, 180000);
    _retryTimer = Timer(Duration(milliseconds: safeDelayMs), () {
      if (!mounted || generation != _scopeGeneration) return;
      unawaited(_invoke(generation));
    });
  }

  void _retryNow() {
    final generation = _scopeGeneration;
    setState(() {
      _response = null;
      _unavailableCode = null;
    });
    unawaited(_invoke(generation));
  }

  String _text({required String ru, required String en}) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, enText: en);

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: ExpatlioDesign.card,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        border: Border.all(color: ExpatlioDesign.border),
      );

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 21,
          ),
        ),
        const SizedBox(width: ExpatlioDesign.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(ru: 'AI-разбор разговора', en: 'AI call feedback'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ExpatlioDesign.text,
                    ),
              ),
              Text(
                _text(
                  ru: 'Подсказки по вашей речи',
                  en: 'Suggestions based on your speech',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ExpatlioDesign.muted,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Row(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: ExpatlioDesign.space12),
        Expanded(
          child: Text(
            _text(
              ru: 'Анализируем вашу речь. Обычно это занимает меньше минуты.',
              en: 'Analyzing your speech. This usually takes under a minute.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String text,
    bool showRetry = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: ExpatlioDesign.muted),
            const SizedBox(width: ExpatlioDesign.space12),
            Expanded(child: Text(text)),
          ],
        ),
        if (showRetry) ...[
          const SizedBox(height: ExpatlioDesign.space12),
          OutlinedButton.icon(
            onPressed: _callInFlight ? null : _retryNow,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_text(ru: 'Повторить', en: 'Retry')),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: ExpatlioDesign.space16),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: ExpatlioDesign.text,
              ),
        ),
      );

  Widget _buildReady(CallFeedbackResult feedback) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${feedback.score}/100',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: ExpatlioDesign.space12),
            Expanded(child: Text(feedback.summary)),
          ],
        ),
        _sectionTitle(_text(ru: 'Что получилось', en: 'Strengths')),
        ...feedback.strengths.map(
          (strength) => Padding(
            padding: const EdgeInsets.only(top: ExpatlioDesign.space8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 18, color: Color(0xFF3A9D65)),
                const SizedBox(width: ExpatlioDesign.space8),
                Expanded(child: Text(strength)),
              ],
            ),
          ),
        ),
        _sectionTitle(_text(ru: 'Как сказать лучше', en: 'Corrections')),
        ...feedback.corrections.map(
          (correction) => Container(
            margin: const EdgeInsets.only(top: ExpatlioDesign.space8),
            padding: const EdgeInsets.all(ExpatlioDesign.space12),
            decoration: BoxDecoration(
              color: ExpatlioDesign.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  correction.original,
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: ExpatlioDesign.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  correction.better,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(correction.explanation),
              ],
            ),
          ),
        ),
        if (feedback.vocabulary.isNotEmpty) ...[
          _sectionTitle(_text(ru: 'Полезные слова', en: 'Vocabulary')),
          ...feedback.vocabulary.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                '${item.term} — ${item.translation}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(item.example),
              trailing: IconButton(
                tooltip: _text(ru: 'Копировать', en: 'Copy'),
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: '${item.term} — ${item.translation}'),
                ),
                icon: const Icon(Icons.copy_rounded, size: 19),
              ),
            ),
          ),
        ],
        _sectionTitle(_text(ru: 'Следующая практика', en: 'Next practice')),
        const SizedBox(height: ExpatlioDesign.space8),
        Text(feedback.nextPractice),
      ],
    );
  }

  Widget _buildContent() {
    final response = _response;
    if (_unavailableCode != null) {
      final featureDisabled = _unavailableCode == 'feature_disabled';
      final dailyLimit = _unavailableCode == 'feedback_daily_limit';
      final windowExpired = _unavailableCode == 'feedback_window_expired';
      return _buildMessage(
        icon: Icons.info_outline_rounded,
        text: _text(
          ru: featureDisabled
              ? 'AI-разбор временно недоступен.'
              : dailyLimit
                  ? 'Лимит AI-разборов на сегодня исчерпан.'
                  : windowExpired
                      ? 'Срок создания разбора для этого звонка истёк.'
                      : 'Не удалось загрузить AI-разбор.',
          en: featureDisabled
              ? 'AI feedback is temporarily unavailable.'
              : dailyLimit
                  ? 'Today’s AI feedback limit has been reached.'
                  : windowExpired
                      ? 'The feedback window for this call has expired.'
                      : 'AI feedback could not be loaded.',
        ),
        showRetry: !featureDisabled && !dailyLimit && !windowExpired,
      );
    }
    if (response == null || response.status == CallFeedbackStatus.pending) {
      return _buildProgress();
    }
    switch (response.status) {
      case CallFeedbackStatus.ready:
        return _buildReady(response.feedback!);
      case CallFeedbackStatus.insufficientText:
        return _buildMessage(
          icon: Icons.short_text_rounded,
          text: _text(
            ru: 'Для разбора не хватило вашей речи. Поговорите чуть дольше в следующем звонке.',
            en: 'There was not enough speech to analyze. Talk a little longer next time.',
          ),
        );
      case CallFeedbackStatus.retryableFailure:
        return _buildMessage(
          icon: Icons.cloud_off_rounded,
          text: _text(
            ru: 'Анализ не завершился. Можно попробовать ещё раз.',
            en: 'The analysis did not finish. You can retry.',
          ),
          showRetry: true,
        );
      case CallFeedbackStatus.terminalFailure:
        return _buildMessage(
          icon: Icons.error_outline_rounded,
          text: _text(
            ru: 'Не удалось подготовить разбор этого звонка.',
            en: 'Feedback could not be prepared for this call.',
          ),
        );
      case CallFeedbackStatus.pending:
        return _buildProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ExpatlioDesign.space16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: ExpatlioDesign.space16),
          _buildContent(),
        ],
      ),
    );
  }
}
