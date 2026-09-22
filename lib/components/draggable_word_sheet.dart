import 'package:flutter/material.dart';

import '/shared_pages/design/expatlio_design.dart';

class DraggableWordSheet extends StatefulWidget {
  const DraggableWordSheet({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<DraggableWordSheet> createState() => _DraggableWordSheetState();
}

class _DraggableWordSheetState extends State<DraggableWordSheet> {
  static const _minimumExtent = 0.18;
  static const _collapsedExtent = 0.46;
  static const _expandedExtent = 0.90;
  static const _dismissVelocity = 900.0;

  ScrollController? _scrollController;
  Offset? _pointerStart;
  Duration? _pointerStartTime;
  bool _pointerStartedAtTop = false;
  bool _dismissed = false;

  void _dismiss() {
    if (_dismissed || !mounted) {
      return;
    }
    _dismissed = true;
    Navigator.of(context).maybePop();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerStart = event.position;
    _pointerStartTime = event.timeStamp;
    final controller = _scrollController;
    _pointerStartedAtTop = controller == null ||
        !controller.hasClients ||
        controller.offset <= 0.5;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final start = _pointerStart;
    if (start != null && event.position.dy - start.dy > 4) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final start = _pointerStart;
    final startedAt = _pointerStartTime;
    _pointerStart = null;
    _pointerStartTime = null;
    if (start == null || startedAt == null || !_pointerStartedAtTop) {
      return;
    }
    final elapsedMicros = (event.timeStamp - startedAt).inMicroseconds;
    if (elapsedMicros <= 0) {
      return;
    }
    final distance = event.position.dy - start.dy;
    final velocity = distance / elapsedMicros * Duration.microsecondsPerSecond;
    if (distance > 24 && velocity >= _dismissVelocity) {
      _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: (_) {
        _pointerStart = null;
        _pointerStartTime = null;
      },
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          if (notification.extent <= _minimumExtent + 0.005) {
            _dismiss();
          }
          return false;
        },
        child: DraggableScrollableSheet(
          expand: false,
          minChildSize: _minimumExtent,
          initialChildSize: _collapsedExtent,
          maxChildSize: _expandedExtent,
          snap: true,
          snapSizes: const <double>[_collapsedExtent],
          builder: (context, scrollController) {
            _scrollController = scrollController;
            return Material(
              color: Colors.transparent,
              child: Container(
                decoration: ExpatlioDesign.sheetDecoration(
                  color: ExpatlioDesign.background,
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsetsDirectional.only(
                    bottom: ExpatlioDesign.space32 +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  children: <Widget>[
                    const _SheetHandle(),
                    widget.child,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final label = Localizations.localeOf(context).languageCode == 'ru'
        ? 'Потяните, чтобы изменить размер окна'
        : 'Drag to resize the sheet';
    return Semantics(
      label: label,
      child: const SizedBox(
        height: 28,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ExpatlioDesign.systemGray5,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
            child: SizedBox(width: 40, height: 4),
          ),
        ),
      ),
    );
  }
}
