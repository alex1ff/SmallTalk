import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileNameField extends StatelessWidget {
  const ProfileNameField({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileFieldLabel(
          text: FFLocalizations.of(context).getVariableText(
            ruText: 'Имя',
            enText: 'Name',
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          autofocus: false,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          textAlignVertical: TextAlignVertical.center,
          obscureText: false,
          decoration: ExpatlioDesign.formFieldDecoration(context),
          style: ExpatlioDesign.formTextStyle(context),
          cursorColor: const Color(0xFF1F1F1F),
          inputFormatters: [
            if (!isAndroid && !isiOS)
              TextInputFormatter.withFunction((oldValue, newValue) {
                return TextEditingValue(
                  selection: newValue.selection,
                  text: newValue.text.toCapitalization(
                    TextCapitalization.sentences,
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }
}

class ProfileReadOnlyField extends StatelessWidget {
  const ProfileReadOnlyField({
    super.key,
    required this.label,
    required this.value,
    this.enabled = true,
    this.onTap,
    this.maxLines = 1,
    this.menuOpen = false,
    this.showDropdownIcon = true,
  });

  final String label;
  final String value;
  final bool enabled;
  final Future<void> Function(BuildContext context)? onTap;
  final int maxLines;
  final bool menuOpen;
  final bool showDropdownIcon;

  @override
  Widget build(BuildContext context) {
    final valueStyle = ExpatlioDesign.formTextStyle(context).copyWith(
      color: enabled ? const Color(0xFF1F1F1F) : const Color(0xFFD0D0D0),
    );

    return Builder(
      builder: (fieldContext) {
        final interactive = enabled && onTap != null;
        return InkWell(
          onTap: interactive ? () => unawaited(onTap!(fieldContext)) : null,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileFieldLabel(text: label),
              const SizedBox(height: ExpatlioDesign.space8),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight:
                      maxLines > 1 ? 60.0 : ExpatlioDesign.formFieldHeight,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFBFB),
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.radiusMedium),
                  border:
                      Border.all(color: const Color(0xFFE7E7E7), width: 1.0),
                ),
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space8,
                    ExpatlioDesign.space12,
                    ExpatlioDesign.space8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: valueStyle,
                      ),
                    ),
                    if (interactive && showDropdownIcon) ...[
                      const SizedBox(width: ExpatlioDesign.space8),
                      Icon(
                        menuOpen
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFFC5C5C6),
                        size: 20.0,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileFieldLabel extends StatelessWidget {
  const _ProfileFieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ExpatlioDesign.formLabelStyle(context),
    );
  }
}
