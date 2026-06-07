import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

import 'flashcard_review_logic.dart';

class FlashcardReviewWidget extends StatefulWidget {
  const FlashcardReviewWidget({
    super.key,
    required this.entries,
    required this.onRemembered,
    this.onCompleted,
  });

  final List<FlashcardSessionEntry> entries;
  final Future<void> Function(
    FlashcardSessionEntry entry, {
    required bool hadAnyMiss,
  }) onRemembered;
  final VoidCallback? onCompleted;

  @override
  State<FlashcardReviewWidget> createState() => _FlashcardReviewWidgetState();
}

class _FlashcardReviewWidgetState extends State<FlashcardReviewWidget> {
  static const double _swipeCommitOffset = 96.0;
  static const double _swipeClampOffset = 120.0;
  static const double _swipeVelocityThreshold = 650.0;

  late List<_QueuedFlashcardEntry> _queue;
  bool _isAnswerVisible = false;
  bool _isSubmitting = false;
  int _completedCards = 0;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _resetQueue();
  }

  @override
  void didUpdateWidget(covariant FlashcardReviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_didEntriesChange(oldWidget.entries, widget.entries)) {
      _resetQueue();
    }
  }

  bool _didEntriesChange(
    List<FlashcardSessionEntry> oldEntries,
    List<FlashcardSessionEntry> newEntries,
  ) {
    if (!identical(oldEntries, newEntries) &&
        oldEntries.length != newEntries.length) {
      return true;
    }

    for (var index = 0;
        index < oldEntries.length && index < newEntries.length;
        index++) {
      if (oldEntries[index].id != newEntries[index].id ||
          oldEntries[index].stage != newEntries[index].stage) {
        return true;
      }
    }

    return !identical(oldEntries, newEntries) &&
        oldEntries.isEmpty != newEntries.isEmpty;
  }

  void _resetQueue() {
    _queue = widget.entries
        .map((entry) => _QueuedFlashcardEntry(entry: entry))
        .toList(growable: true);
    _isAnswerVisible = false;
    _isSubmitting = false;
    _completedCards = 0;
    _dragOffset = 0.0;
  }

  _QueuedFlashcardEntry? get _currentQueuedEntry =>
      _queue.isEmpty ? null : _queue.first;

  Future<void> _handleRemembered() async {
    final current = _currentQueuedEntry;
    if (current == null || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _dragOffset = 0.0;
    });

    try {
      await widget.onRemembered(
        current.entry,
        hadAnyMiss: current.hadAnyMiss,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Не удалось обновить прогресс. Попробуйте ещё раз.',
              enText: 'Failed to update progress. Please try again.',
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _queue.removeAt(0);
      _completedCards = _completedCards + 1;
      _isSubmitting = false;
    });

    if (_queue.isEmpty) {
      widget.onCompleted?.call();
    }
  }

  void _handleNotRemembered() {
    final current = _currentQueuedEntry;
    if (current == null || _isSubmitting) {
      return;
    }

    setState(() {
      final movedEntry = _queue.removeAt(0).copyWith(hadAnyMiss: true);
      _queue.add(movedEntry);
      _dragOffset = 0.0;
    });
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx)
          .clamp(-_swipeClampOffset, _swipeClampOffset);
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_isSubmitting) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0.0;
    final shouldRemember = _dragOffset >= _swipeCommitOffset ||
        velocity >= _swipeVelocityThreshold;
    final shouldForget = _dragOffset <= -_swipeCommitOffset ||
        velocity <= -_swipeVelocityThreshold;

    if (shouldRemember) {
      _handleRemembered();
      return;
    }

    if (shouldForget) {
      _handleNotRemembered();
      return;
    }

    setState(() {
      _dragOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentQueuedEntry;
    if (current == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: ExpatlioDesign.space12,
            bottom: ExpatlioDesign.space12,
          ),
          child: Text(
            key: const Key('flashcardProgressText'),
            FFLocalizations.of(context).getVariableText(
              ruText:
                  'Осталось ${_queue.length} • Завершено $_completedCards из ${widget.entries.length}',
              enText:
                  '${_queue.length} left • Completed $_completedCards of ${widget.entries.length}',
            ),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: ExpatlioDesign.muted,
                  fontSize: 15.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              _buildSwipeBackground(context),
              GestureDetector(
                onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                onHorizontalDragEnd: _handleHorizontalDragEnd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(_dragOffset, 0.0, 0.0),
                  child: _buildCard(context, current.entry),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space20),
        _buildDecisionButtons(context),
      ],
    );
  }

  Widget _buildSwipeBackground(BuildContext context) {
    return Positioned.fill(
      child: Row(
        children: [
          Expanded(
            child: Container(
              margin:
                  const EdgeInsets.symmetric(vertical: ExpatlioDesign.space4),
              decoration: BoxDecoration(
                color: const Color(0x14FF3B30),
                borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                  horizontal: ExpatlioDesign.space24),
              child: Text(
                FFLocalizations.of(context).getVariableText(
                  ruText: 'Не помню',
                  enText: 'Forgot',
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: const Color(0xFFFF3B30),
                      fontSize: 15.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin:
                  const EdgeInsets.symmetric(vertical: ExpatlioDesign.space4),
              decoration: BoxDecoration(
                color: const Color(0x141FBF75),
                borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(
                  horizontal: ExpatlioDesign.space24),
              child: Text(
                FFLocalizations.of(context).getVariableText(
                  ruText: 'Помню',
                  enText: 'Remembered',
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: const Color(0xFF1FBF75),
                      fontSize: 15.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, FlashcardSessionEntry entry) {
    final cardColor = ExpatlioDesign.card;
    final primaryTextColor = ExpatlioDesign.text;
    final secondaryTextColor = ExpatlioDesign.muted;
    final accentColor = ExpatlioDesign.primary;
    final hasSourceMetadata =
        (entry.sourceTranscription?.trim().isNotEmpty ?? false) ||
            entry.sourceSynonyms.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: ExpatlioDesign.space4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        border: Border.all(color: ExpatlioDesign.border),
        boxShadow: [
          BoxShadow(
            blurRadius: 12.0,
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0.0, 4.0),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            ExpatlioDesign.space24,
            ExpatlioDesign.space32,
            ExpatlioDesign.space24,
            ExpatlioDesign.space32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ExpatlioDesign.space12,
                      vertical: ExpatlioDesign.space8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(ExpatlioDesign.controlRadius),
                  ),
                  child: Text(
                    _directionLabel(context, entry.direction),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          color: accentColor,
                          fontSize: 15.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  key: const Key('answerVisibilityToggle'),
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.radiusLarge),
                  onTap: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _isAnswerVisible = !_isAnswerVisible;
                          });
                        },
                  child: Container(
                    width: 40.0,
                    height: 40.0,
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isAnswerVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: secondaryTextColor,
                      size: 18.0,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      vertical: ExpatlioDesign.space24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.promptText,
                        textAlign: TextAlign.center,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              color: primaryTextColor,
                              fontSize: 34.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (hasSourceMetadata) ...[
                        const SizedBox(height: ExpatlioDesign.space12),
                        _buildSourceMetadata(context, entry),
                      ],
                      const SizedBox(height: ExpatlioDesign.space32),
                      SizedBox(
                        height: 56.0,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            layoutBuilder: (currentChild, previousChildren) {
                              return Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            child: _isAnswerVisible
                                ? Text(
                                    key: const Key('flashcardAnswerText'),
                                    entry.answerText,
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: accentColor,
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  )
                                : ConstrainedBox(
                                    key: const Key('flashcardAnswerHint'),
                                    constraints:
                                        const BoxConstraints(maxWidth: 320.0),
                                    child: Text(
                                      FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText:
                                            'Ответ можно открыть по иконке глаза, но это не обязательно.',
                                        enText:
                                            'You can open the answer with the eye icon, but it is optional.',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: secondaryTextColor,
                                            fontSize: 15.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceMetadata(
    BuildContext context,
    FlashcardSessionEntry entry,
  ) {
    final transcription = _formatTranscription(entry.sourceTranscription);
    final synonyms = entry.sourceSynonyms;
    final hasTranscription = transcription.isNotEmpty;
    final hasSynonyms = synonyms.isNotEmpty;

    if (!hasTranscription && !hasSynonyms) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const Key('sourceMetadata'),
      children: [
        if (hasTranscription)
          Text(
            key: const Key('sourceTranscriptionText'),
            transcription,
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: ExpatlioDesign.muted,
                  fontSize: 15.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w500,
                ),
          ),
        if (hasSynonyms) ...[
          if (hasTranscription) const SizedBox(height: ExpatlioDesign.space12),
          Wrap(
            spacing: ExpatlioDesign.space8,
            runSpacing: ExpatlioDesign.space8,
            alignment: WrapAlignment.center,
            children: synonyms
                .map(
                  (synonym) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ExpatlioDesign.space12,
                      vertical: ExpatlioDesign.space8,
                    ),
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.background,
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusLarge),
                    ),
                    child: Text(
                      key: ValueKey<String>('sourceSynonym_${synonym.text}'),
                      synonym.text,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: ExpatlioDesign.text,
                            fontSize: 13.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }

  String _formatTranscription(String? transcription) {
    final normalized = transcription?.trim() ?? '';
    if (normalized.isEmpty) {
      return '';
    }

    if (normalized.startsWith('[') && normalized.endsWith(']')) {
      return normalized;
    }

    return '[$normalized]';
  }

  Widget _buildDecisionButtons(BuildContext context) {
    return Row(
      key: const ValueKey<String>('decisionActions'),
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('forgetButton'),
            onPressed: _isSubmitting ? null : _handleNotRemembered,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56.0),
              side: const BorderSide(
                color: Color(0xFFFF3B30),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
              ),
            ),
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Не помню',
                enText: 'I forgot',
              ),
              style: ExpatlioDesign.buttonTextStyle(
                context,
                color: const Color(0xFFFF3B30),
              ),
            ),
          ),
        ),
        const SizedBox(width: ExpatlioDesign.space12),
        Expanded(
          child: ElevatedButton(
            key: const Key('rememberButton'),
            onPressed: _isSubmitting ? null : _handleRemembered,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1FBF75),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
              ),
              elevation: 0.0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18.0,
                    height: 18.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    FFLocalizations.of(context).getVariableText(
                      ruText: 'Помню',
                      enText: 'I remember',
                    ),
                    style: ExpatlioDesign.buttonTextStyle(context),
                  ),
          ),
        ),
      ],
    );
  }

  String _directionLabel(
    BuildContext context,
    FlashcardPromptDirection direction,
  ) {
    switch (direction) {
      case FlashcardPromptDirection.ruToEn:
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Русский → English',
          enText: 'Russian → English',
        );
      case FlashcardPromptDirection.enToRu:
        return FFLocalizations.of(context).getVariableText(
          ruText: 'English → Русский',
          enText: 'English → Russian',
        );
    }
  }
}

class _QueuedFlashcardEntry {
  const _QueuedFlashcardEntry({
    required this.entry,
    this.hadAnyMiss = false,
  });

  final FlashcardSessionEntry entry;
  final bool hadAnyMiss;

  _QueuedFlashcardEntry copyWith({
    FlashcardSessionEntry? entry,
    bool? hadAnyMiss,
  }) {
    return _QueuedFlashcardEntry(
      entry: entry ?? this.entry,
      hadAnyMiss: hadAnyMiss ?? this.hadAnyMiss,
    );
  }
}
