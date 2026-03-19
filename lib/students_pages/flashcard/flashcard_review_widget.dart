import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
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
    if (!identical(oldEntries, newEntries) && oldEntries.length != newEntries.length) {
      return true;
    }

    for (var index = 0; index < oldEntries.length && index < newEntries.length; index++) {
      if (oldEntries[index].id != newEntries[index].id ||
          oldEntries[index].stage != newEntries[index].stage) {
        return true;
      }
    }

    return !identical(oldEntries, newEntries) && oldEntries.isEmpty != newEntries.isEmpty;
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
    if (current == null || !_isAnswerVisible || _isSubmitting) {
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
      _isAnswerVisible = false;
      _isSubmitting = false;
    });

    if (_queue.isEmpty) {
      widget.onCompleted?.call();
    }
  }

  void _handleNotRemembered() {
    final current = _currentQueuedEntry;
    if (current == null || !_isAnswerVisible || _isSubmitting) {
      return;
    }

    setState(() {
      final movedEntry = _queue.removeAt(0).copyWith(hadAnyMiss: true);
      _queue.add(movedEntry);
      _isAnswerVisible = false;
      _dragOffset = 0.0;
    });
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isAnswerVisible || _isSubmitting) {
      return;
    }

    setState(() {
      _dragOffset =
          (_dragOffset + details.delta.dx).clamp(-_swipeClampOffset, _swipeClampOffset);
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!_isAnswerVisible || _isSubmitting) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0.0;
    final shouldRemember =
        _dragOffset >= _swipeCommitOffset || velocity >= _swipeVelocityThreshold;
    final shouldForget =
        _dragOffset <= -_swipeCommitOffset || velocity <= -_swipeVelocityThreshold;

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
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            FFLocalizations.of(context).getVariableText(
              ruText:
                  'Осталось ${_queue.length} • Завершено $_completedCards из ${widget.entries.length}',
              enText:
                  '${_queue.length} left • Completed $_completedCards of ${widget.entries.length}',
            ),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: FlutterFlowTheme.of(context).secondaryText,
                  fontSize: 14.0,
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
        const SizedBox(height: 20.0),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isAnswerVisible
              ? _buildDecisionButtons(context)
              : _buildRevealButton(context),
        ),
      ],
    );
  }

  Widget _buildSwipeBackground(BuildContext context) {
    return Positioned.fill(
      child: Row(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0x14FF3B30),
                borderRadius: BorderRadius.circular(28.0),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0x141FBF75),
                borderRadius: BorderRadius.circular(28.0),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
    final cardColor = FlutterFlowTheme.of(context).primaryBackground;
    final primaryTextColor = FlutterFlowTheme.of(context).primaryText;
    final secondaryTextColor = FlutterFlowTheme.of(context).secondaryText;
    final accentColor = FlutterFlowTheme.of(context).primary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28.0),
        boxShadow: [
          BoxShadow(
            blurRadius: 18.0,
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0.0, 8.0),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Text(
                _directionLabel(context, entry.direction),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: accentColor,
                      fontSize: 13.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 24.0),
            Text(
              entry.promptText,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Cool',
                    color: primaryTextColor,
                    fontSize: 34.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                  ),
            ),
            const SizedBox(height: 16.0),
            Text(
              _isAnswerVisible
                  ? FFLocalizations.of(context).getVariableText(
                      ruText: 'Правильный ответ',
                      enText: 'Correct answer',
                    )
                  : FFLocalizations.of(context).getVariableText(
                      ruText: 'Сначала вспомните ответ, затем откройте его.',
                      enText: 'Recall the answer first, then reveal it.',
                    ),
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    color: secondaryTextColor,
                    fontSize: 15.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                  ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: _isAnswerVisible
                  ? Column(
                      children: [
                        const SizedBox(height: 24.0),
                        Container(
                          width: 48.0,
                          height: 1.0,
                          color: secondaryTextColor.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 24.0),
                        Text(
                          entry.answerText,
                          textAlign: TextAlign.center,
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                fontFamily: 'Cool',
                                color: primaryTextColor,
                                fontSize: 30.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.normal,
                              ),
                        ),
                        if ((entry.exampleSource ?? '').isNotEmpty ||
                            (entry.exampleTranslation ?? '').isNotEmpty) ...[
                          const SizedBox(height: 24.0),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).secondaryBackground,
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            child: Column(
                              children: [
                                if ((entry.exampleSource ?? '').isNotEmpty)
                                  Text(
                                    entry.exampleSource!,
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: primaryTextColor,
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w500,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                                if ((entry.exampleTranslation ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 8.0),
                                  Text(
                                    entry.exampleTranslation!,
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
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevealButton(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('revealAction'),
      width: double.infinity,
      child: ElevatedButton(
        key: const Key('revealButton'),
        onPressed: _isSubmitting
            ? null
            : () {
                setState(() {
                  _isAnswerVisible = true;
                });
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: FlutterFlowTheme.of(context).primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22.0),
          ),
          elevation: 0.0,
        ),
        child: Text(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Показать ответ',
            enText: 'Show answer',
          ),
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'sf pro display',
                color: Colors.white,
                fontSize: 16.0,
                letterSpacing: 0.0,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
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
                borderRadius: BorderRadius.circular(22.0),
              ),
            ),
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Не помню',
                enText: 'I forgot',
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    color: const Color(0xFFFF3B30),
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: ElevatedButton(
            key: const Key('rememberButton'),
            onPressed: _isSubmitting ? null : _handleRemembered,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1FBF75),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22.0),
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
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          color: Colors.white,
                          fontSize: 16.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                        ),
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
          ruText: 'Русский -> English',
          enText: 'Russian -> English',
        );
      case FlashcardPromptDirection.enToRu:
        return FFLocalizations.of(context).getVariableText(
          ruText: 'English -> Русский',
          enText: 'English -> Russian',
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
