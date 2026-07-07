import '/flutter_flow/flutter_flow_util.dart';
import '/components/ux_empty_state.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'empty_model.dart';
export 'empty_model.dart';

class EmptyWidget extends StatefulWidget {
  const EmptyWidget({
    super.key,
    required this.txt,
    this.shrinkWrap = false,
    this.topPadding = ExpatlioDesign.space64,
  });

  final String? txt;
  final bool shrinkWrap;
  final double topPadding;

  @override
  State<EmptyWidget> createState() => _EmptyWidgetState();
}

class _EmptyWidgetState extends State<EmptyWidget> {
  late EmptyModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EmptyModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UxEmptyState(
      title: FFLocalizations.of(context).getVariableText(
        ruText: 'Здесь пока пусто',
        enText: 'Nothing here yet',
      ),
      message: valueOrDefault<String>(
        widget.txt,
        '-',
      ),
      shrinkWrap: widget.shrinkWrap,
      topPadding: widget.topPadding,
    );
  }
}
