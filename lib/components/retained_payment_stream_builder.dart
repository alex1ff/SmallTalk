import 'package:flutter/material.dart';

enum RetainedPaymentStreamPhase {
  initialLoading,
  refreshing,
  data,
  errorWithData,
  errorWithoutData,
}

class RetainedPaymentStreamView<T> {
  const RetainedPaymentStreamView({
    required this.phase,
    required this.data,
    required this.hasError,
  });

  final RetainedPaymentStreamPhase phase;
  final List<T> data;
  final bool hasError;
}

class RetainedPaymentStreamBuilder<T> extends StatefulWidget {
  const RetainedPaymentStreamBuilder({
    super.key,
    required this.ownerKey,
    required this.stream,
    required this.builder,
  });

  final String ownerKey;
  final Stream<List<T>> stream;
  final Widget Function(
    BuildContext context,
    RetainedPaymentStreamView<T> view,
  ) builder;

  @override
  State<RetainedPaymentStreamBuilder<T>> createState() =>
      _RetainedPaymentStreamBuilderState<T>();
}

class _RetainedPaymentStreamBuilderState<T>
    extends State<RetainedPaymentStreamBuilder<T>> {
  List<T> _latestData = const [];
  bool _hasSuccessfulResult = false;
  int _streamGeneration = 0;

  @override
  void didUpdateWidget(RetainedPaymentStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerKey != widget.ownerKey) {
      _latestData = const [];
      _hasSuccessfulResult = false;
      _streamGeneration += 1;
    } else if (!identical(oldWidget.stream, widget.stream)) {
      _streamGeneration += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      key: ValueKey<String>(
        'retained_payment_stream_${widget.ownerKey}_$_streamGeneration',
      ),
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _latestData = List<T>.unmodifiable(snapshot.data!);
          _hasSuccessfulResult = true;
        }

        final phase = switch ((snapshot.hasError, _hasSuccessfulResult)) {
          (true, true) => RetainedPaymentStreamPhase.errorWithData,
          (true, false) => RetainedPaymentStreamPhase.errorWithoutData,
          (false, true)
              when snapshot.connectionState == ConnectionState.waiting =>
            RetainedPaymentStreamPhase.refreshing,
          (false, true) => RetainedPaymentStreamPhase.data,
          _ => RetainedPaymentStreamPhase.initialLoading,
        };

        return widget.builder(
          context,
          RetainedPaymentStreamView<T>(
            phase: phase,
            data: _latestData,
            hasError: snapshot.hasError,
          ),
        );
      },
    );
  }
}
