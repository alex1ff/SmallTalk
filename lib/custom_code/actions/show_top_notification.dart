// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'index.dart'; // Imports other custom actions

import 'dart:async';
import '/components/pop/pop_widget.dart';

Future showTopNotification(
  BuildContext context,
  String header,
  String? text, // Сделали необязательн
  bool isError, // Добавлен параметр для индикации ошибки
) async {
  final OverlayState? overlayState = Overlay.of(context, rootOverlay: true);
  if (overlayState == null) {
    return;
  }
  OverlayEntry? overlayEntry;
  Timer? autoDismissTimer;
  bool isClosing = false;

  // Создаем AnimationController для точного контроля
  final AnimationController controller = AnimationController(
    duration: Duration(milliseconds: 500),
    vsync: overlayState,
  );

  // Пружинистая анимация появления (как в iOS)
  final Animation<double> slideAnimation = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutBack, // Пружинящий эффект
  );

  Future<void> dismiss({bool animate = true}) async {
    if (isClosing) {
      return;
    }
    isClosing = true;
    autoDismissTimer?.cancel();
    if (animate) {
      try {
        await controller.reverse();
      } catch (_) {}
    }
    overlayEntry?.remove();
    controller.dispose();
  }

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              0,
              -100 * (1 - slideAnimation.value), // Slide down с верха
            ),
            child: Opacity(
              opacity: slideAnimation.value
                  .clamp(0.0, 1.0), // FIX: clamp для предотвращения ошибки
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  right: 8,
                ),
                child: child,
              ),
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) {
              dismiss(animate: false);
            },
            child: PopWidget(
              header: header,
              text: text ?? '', // Если text null, передаем пустую строку
              isError: isError, // Передаем параметр isError в компонент
            ),
          ),
        ),
      ),
    ),
  );

  // Показываем
  overlayState.insert(overlayEntry);
  controller.forward().then((_) {
    if (!isClosing) {
      autoDismissTimer = Timer(
        Duration(seconds: 3),
        () => dismiss(),
      );
    }
  }).catchError((_) {});
}
