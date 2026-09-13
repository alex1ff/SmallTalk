import 'package:flutter/material.dart';

import '/shared_pages/design/expatlio_design.dart';

const ValueKey<String> chatComposerCapsuleKey =
    ValueKey<String>('chat_composer_capsule');
const ValueKey<String> chatComposerSendCircleKey =
    ValueKey<String>('chat_composer_send_circle');

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSendPressed,
    required this.hintText,
    required this.sendButtonSemanticLabel,
    required this.enabled,
    required this.isSending,
    this.inputKey,
    this.sendButtonKey,
    this.surfaceColor = ExpatlioDesign.background,
    this.capsuleColor = ExpatlioDesign.card,
    this.borderColor = ExpatlioDesign.separator,
    this.textColor,
    this.hintColor,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSendPressed;
  final String hintText;
  final String sendButtonSemanticLabel;
  final bool enabled;
  final bool isSending;
  final Key? inputKey;
  final Key? sendButtonKey;
  final Color surfaceColor;
  final Color capsuleColor;
  final Color borderColor;
  final Color? textColor;
  final Color? hintColor;

  void _sendIfAvailable() {
    if (enabled && !isSending && controller.text.trim().isNotEmpty) {
      onSendPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final canSend =
            enabled && !isSending && controller.text.trim().isNotEmpty;

        return DecoratedBox(
          decoration: BoxDecoration(color: surfaceColor),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space16,
              ExpatlioDesign.space8,
              ExpatlioDesign.space16,
              ExpatlioDesign.space8 +
                  ExpatlioDesign.bottomBarSafePadding(context),
            ),
            child: DecoratedBox(
              key: chatComposerCapsuleKey,
              decoration: BoxDecoration(
                color: capsuleColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: inputKey,
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        hintText: hintText,
                        hintStyle: ExpatlioDesign.formTextStyle(
                          context,
                          enabled: false,
                        ).copyWith(color: hintColor),
                        contentPadding:
                            const EdgeInsetsDirectional.fromSTEB(16, 11, 8, 11),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                      style: ExpatlioDesign.formTextStyle(
                        context,
                        enabled: enabled,
                      ).copyWith(color: textColor),
                      onFieldSubmitted: (_) => _sendIfAvailable(),
                    ),
                  ),
                  Semantics(
                    key: sendButtonKey,
                    container: true,
                    button: true,
                    enabled: canSend,
                    label: sendButtonSemanticLabel,
                    onTap: canSend ? onSendPressed : null,
                    excludeSemantics: true,
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 36,
                          child: Material(
                            key: chatComposerSendCircleKey,
                            color: canSend || isSending
                                ? ExpatlioDesign.primary
                                : ExpatlioDesign.secondarySystemFill,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              excludeFromSemantics: true,
                              onTap: enabled && !isSending
                                  ? _sendIfAvailable
                                  : null,
                              child: Center(
                                child: isSending
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 24,
                                        color: canSend
                                            ? Colors.white
                                            : ExpatlioDesign.muted,
                                      ),
                              ),
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
        );
      },
    );
  }
}
