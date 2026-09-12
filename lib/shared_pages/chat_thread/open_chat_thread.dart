import 'dart:async';

import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/components/ux_error_state.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'chat_thread_widget.dart';

const ValueKey<String> deferredChatThreadLoadingKey =
    ValueKey<String>('deferred_chat_thread_loading');
const ValueKey<String> deferredChatThreadErrorKey =
    ValueKey<String>('deferred_chat_thread_error');
const ValueKey<String> deferredChatThreadRetryButtonKey =
    ValueKey<String>('deferred_chat_thread_retry_button');

typedef ChatConversationPreparation = Future<void> Function();

Future<void> openChatThread(
  BuildContext context, {
  required DocumentReference? conversationRef,
  ConversationsRecord? initialConversation,
  ChatPartnerPreview? initialPartnerPreview,
  ChatConversationPreparation? preparation,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (context) => preparation == null
          ? ChatThreadWidget(
              conversationRef: conversationRef,
              initialConversation: initialConversation,
              initialPartnerPreview: initialPartnerPreview,
            )
          : DeferredChatThreadWidget(
              conversationRef: conversationRef,
              initialConversation: initialConversation,
              initialPartnerPreview: initialPartnerPreview,
              preparation: preparation,
            ),
    ),
  );
}

enum _DeferredChatThreadStatus {
  loading,
  error,
  ready,
}

class DeferredChatThreadWidget extends StatefulWidget {
  const DeferredChatThreadWidget({
    super.key,
    required this.conversationRef,
    required this.preparation,
    this.initialConversation,
    this.initialPartnerPreview,
  });

  final DocumentReference? conversationRef;
  final ConversationsRecord? initialConversation;
  final ChatPartnerPreview? initialPartnerPreview;
  final ChatConversationPreparation preparation;

  @override
  State<DeferredChatThreadWidget> createState() =>
      _DeferredChatThreadWidgetState();
}

class _DeferredChatThreadWidgetState extends State<DeferredChatThreadWidget> {
  _DeferredChatThreadStatus _status = _DeferredChatThreadStatus.loading;
  bool _attemptInFlight = false;
  int _attemptGeneration = 0;

  @override
  void initState() {
    super.initState();
    _startPreparation(updateState: false);
  }

  @override
  void didUpdateWidget(DeferredChatThreadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationRef?.path == widget.conversationRef?.path &&
        identical(oldWidget.preparation, widget.preparation) &&
        identical(oldWidget.initialConversation, widget.initialConversation)) {
      return;
    }
    _attemptGeneration += 1;
    _attemptInFlight = false;
    _status = _DeferredChatThreadStatus.loading;
    _startPreparation(updateState: false);
  }

  @override
  void dispose() {
    _attemptGeneration += 1;
    super.dispose();
  }

  void _startPreparation({bool updateState = true}) {
    if (_attemptInFlight) {
      return;
    }
    final generation = ++_attemptGeneration;
    _attemptInFlight = true;
    if (updateState) {
      setState(() {
        _status = _DeferredChatThreadStatus.loading;
      });
    }
    unawaited(_completePreparation(generation));
  }

  Future<void> _completePreparation(int generation) async {
    try {
      await widget.preparation();
    } catch (_) {
      if (!mounted || generation != _attemptGeneration) {
        return;
      }
      setState(() {
        _attemptInFlight = false;
        _status = _DeferredChatThreadStatus.error;
      });
      return;
    }
    if (!mounted || generation != _attemptGeneration) {
      return;
    }
    setState(() {
      _attemptInFlight = false;
      _status = _DeferredChatThreadStatus.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _DeferredChatThreadStatus.ready) {
      return ChatThreadWidget(
        conversationRef: widget.conversationRef,
        initialConversation: widget.initialConversation,
        initialPartnerPreview: widget.initialPartnerPreview,
      );
    }

    final openingLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Открываем чат',
      enText: 'Opening chat',
    );
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
        child: _status == _DeferredChatThreadStatus.loading
            ? Center(
                child: Semantics(
                  key: deferredChatThreadLoadingKey,
                  container: true,
                  liveRegion: true,
                  label: openingLabel,
                  child: const ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.8),
                    ),
                  ),
                ),
              )
            : Center(
                child: UxErrorState(
                  stateKey: deferredChatThreadErrorKey,
                  title: FFLocalizations.of(context).getVariableText(
                    ruText: 'Не удалось открыть чат',
                    enText: 'Could not open chat',
                  ),
                  message: FFLocalizations.of(context).getVariableText(
                    ruText: 'Проверьте подключение и попробуйте снова.',
                    enText: 'Check your connection and try again.',
                  ),
                  retryLabel: FFLocalizations.of(context).getVariableText(
                    ruText: 'Повторить',
                    enText: 'Retry',
                  ),
                  retrySemanticsLabel:
                      FFLocalizations.of(context).getVariableText(
                    ruText: 'Повторить открытие чата',
                    enText: 'Retry opening chat',
                  ),
                  retryButtonKey: deferredChatThreadRetryButtonKey,
                  onRetry: _attemptInFlight ? null : _startPreparation,
                ),
              ),
      ),
    );
  }
}
