import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';

const ValueKey<String> eventCreateTitleLabelKey =
    ValueKey<String>('event_create_title_label');
const ValueKey<String> eventCreateTitleFieldSemanticsKey =
    ValueKey<String>('event_create_title_field_semantics');
const ValueKey<String> eventCreateTitleFieldKey =
    ValueKey<String>('event_create_title_field');
const ValueKey<String> eventCreateDescriptionLabelKey =
    ValueKey<String>('event_create_description_label');
const ValueKey<String> eventCreateDescriptionFieldSemanticsKey =
    ValueKey<String>('event_create_description_field_semantics');
const ValueKey<String> eventCreateDescriptionFieldKey =
    ValueKey<String>('event_create_description_field');

class EventCreateWidget extends StatefulWidget {
  const EventCreateWidget({super.key});

  static String routeName = 'eventCreate';
  static String routePath = '/events/create';

  @override
  State<EventCreateWidget> createState() => _EventCreateWidgetState();
}

class _EventCreateWidgetState extends State<EventCreateWidget> {
  final _formKey = GlobalKey<FormState>();
  final _titleTextController = TextEditingController();
  final _descriptionTextController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  @override
  void dispose() {
    _titleTextController.dispose();
    _descriptionTextController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _EventCreateTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space32,
                ),
                children: [
                  Align(
                    alignment: AlignmentDirectional.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _EventCreateTextField(
                              labelKey: eventCreateTitleLabelKey,
                              semanticsKey: eventCreateTitleFieldSemanticsKey,
                              fieldKey: eventCreateTitleFieldKey,
                              label:
                                  FFLocalizations.of(context).getVariableText(
                                ruText: 'Название',
                                enText: 'Title',
                              ),
                              hintText:
                                  FFLocalizations.of(context).getVariableText(
                                ruText: 'Разговорный клуб: кофе и английский',
                                enText: 'Conversation club: coffee and English',
                              ),
                              controller: _titleTextController,
                              focusNode: _titleFocusNode,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: () {
                                _descriptionFocusNode.requestFocus();
                              },
                            ),
                            const SizedBox(height: ExpatlioDesign.space20),
                            _EventCreateTextField(
                              labelKey: eventCreateDescriptionLabelKey,
                              semanticsKey:
                                  eventCreateDescriptionFieldSemanticsKey,
                              fieldKey: eventCreateDescriptionFieldKey,
                              label:
                                  FFLocalizations.of(context).getVariableText(
                                ruText: 'Описание',
                                enText: 'Description',
                              ),
                              hintText:
                                  FFLocalizations.of(context).getVariableText(
                                ruText: 'Расскажите, что будет на встрече',
                                enText:
                                    'Tell people what will happen at the meetup',
                              ),
                              controller: _descriptionTextController,
                              focusNode: _descriptionFocusNode,
                              textInputAction: TextInputAction.newline,
                              keyboardType: TextInputType.multiline,
                              minLines: 4,
                              maxLines: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCreateTextField extends StatelessWidget {
  const _EventCreateTextField({
    required this.labelKey,
    required this.semanticsKey,
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.focusNode,
    this.hintText,
    this.textInputAction,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.onFieldSubmitted,
  });

  final Key labelKey;
  final Key semanticsKey;
  final Key fieldKey;
  final String label;
  final String? hintText;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final int? minLines;
  final int maxLines;
  final VoidCallback? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: labelKey,
          label,
          style: ExpatlioDesign.formLabelStyle(context),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Semantics(
          key: semanticsKey,
          container: true,
          textField: true,
          multiline: maxLines > 1,
          label: label,
          hint: hintText,
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: textInputAction,
            keyboardType: keyboardType,
            minLines: minLines,
            maxLines: maxLines,
            onFieldSubmitted: (_) => onFieldSubmitted?.call(),
            decoration: ExpatlioDesign.formFieldDecoration(
              context,
              hintText: hintText,
              maxLines: maxLines,
            ),
            style: ExpatlioDesign.formTextStyle(context),
            cursorColor: ExpatlioDesign.primary,
            enableInteractiveSelection: true,
          ),
        ),
      ],
    );
  }
}

class _EventCreateTopBar extends StatelessWidget {
  const _EventCreateTopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ExpatlioDesign.pageHeaderHeight,
      child: Row(
        children: [
          FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 24,
            buttonSize: 48,
            icon: Icon(
              FFIcons.kchevronLeft,
              color: ExpatlioDesign.text,
              size: 24,
            ),
            onPressed: () => context.safePop(),
          ),
          Expanded(
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Создать событие',
                enText: 'Create event',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.pageHeaderTitleStyle(context),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
