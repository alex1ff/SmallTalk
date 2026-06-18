import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/event_language_catalog.dart';

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
const ValueKey<String> eventCreateLanguageLabelKey =
    ValueKey<String>('event_create_language_label');
const ValueKey<String> eventCreateLanguageSelectorSemanticsKey =
    ValueKey<String>('event_create_language_selector_semantics');
const ValueKey<String> eventCreateLanguageSelectorKey =
    ValueKey<String>('event_create_language_selector');
const ValueKey<String> eventCreateLanguageSheetKey =
    ValueKey<String>('event_create_language_sheet');

ValueKey<String> eventCreateLanguageOptionKey(String code) =>
    ValueKey<String>('event_create_language_option_$code');

class EventCreateWidget extends StatefulWidget {
  const EventCreateWidget({
    super.key,
    this.languageCatalogOverride,
    this.initialLanguageCode,
    this.onLanguageCodeChanged,
  });

  static String routeName = 'eventCreate';
  static String routePath = '/events/create';

  final EventLanguageCatalog? languageCatalogOverride;
  final String? initialLanguageCode;
  final ValueChanged<String>? onLanguageCodeChanged;

  @override
  State<EventCreateWidget> createState() => _EventCreateWidgetState();
}

class _EventCreateWidgetState extends State<EventCreateWidget> {
  final _formKey = GlobalKey<FormState>();
  final _titleTextController = TextEditingController();
  final _descriptionTextController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  Future<EventLanguageCatalog>? _languageCatalogFuture;
  AssetBundle? _languageCatalogBundle;
  String? _selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    _selectedLanguageCode = widget.initialLanguageCode;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    final previousBundle = _languageCatalogBundle;
    _languageCatalogBundle = bundle;
    if (_languageCatalogFuture == null ||
        (widget.languageCatalogOverride == null && previousBundle != bundle)) {
      _languageCatalogFuture = _loadLanguageCatalog(bundle: bundle);
    }
  }

  @override
  void didUpdateWidget(covariant EventCreateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.languageCatalogOverride != widget.languageCatalogOverride) {
      _languageCatalogFuture = _loadLanguageCatalog(
        bundle: _languageCatalogBundle ?? DefaultAssetBundle.of(context),
      );
    }
    if (oldWidget.initialLanguageCode != widget.initialLanguageCode) {
      _selectedLanguageCode = widget.initialLanguageCode;
    }
  }

  @override
  void dispose() {
    _titleTextController.dispose();
    _descriptionTextController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  Future<EventLanguageCatalog> _loadLanguageCatalog({
    AssetBundle? bundle,
  }) async {
    final override = widget.languageCatalogOverride;
    if (override != null) {
      return override;
    }
    return EventLanguageCatalog.loadFromAsset(
      bundle: bundle ?? DefaultAssetBundle.of(context),
    );
  }

  String _resolvedSelectedLanguageCode(EventLanguageCatalog catalog) {
    final selected = catalog.resolvePrimaryLanguageCode(_selectedLanguageCode);
    if (selected != null) {
      return selected;
    }
    final popular = catalog.popularLanguages(limit: 1);
    if (popular.isNotEmpty) {
      return popular.first.code;
    }
    return catalog.languages.first.code;
  }

  Future<void> _showLanguageSelector(
    EventLanguageCatalog catalog,
    String selectedLanguageCode,
  ) async {
    final selectedCode = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventCreateLanguageSheet(
        catalog: catalog,
        selectedLanguageCode: selectedLanguageCode,
      ),
    );
    if (selectedCode == null || !mounted) {
      return;
    }
    setState(() {
      _selectedLanguageCode = selectedCode;
    });
    widget.onLanguageCodeChanged?.call(selectedCode);
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
                            const SizedBox(height: ExpatlioDesign.space20),
                            FutureBuilder<EventLanguageCatalog>(
                              future: _languageCatalogFuture,
                              builder: (context, snapshot) {
                                final catalog = snapshot.data;
                                if (catalog == null) {
                                  return _EventCreateLanguageSelector(
                                    state: snapshot.hasError
                                        ? _EventCreateLanguageSelectorState
                                            .error
                                        : _EventCreateLanguageSelectorState
                                            .loading,
                                  );
                                }
                                final selectedLanguageCode =
                                    _resolvedSelectedLanguageCode(catalog);
                                return _EventCreateLanguageSelector(
                                  state: _EventCreateLanguageSelectorState
                                      .selected,
                                  selectedLabel:
                                      _eventCreateLanguageDisplayName(
                                    context: context,
                                    catalog: catalog,
                                    languageCode: selectedLanguageCode,
                                  ),
                                  onPressed: () => _showLanguageSelector(
                                    catalog,
                                    selectedLanguageCode,
                                  ),
                                );
                              },
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

enum _EventCreateLanguageSelectorState {
  loading,
  error,
  selected,
}

class _EventCreateLanguageSelector extends StatelessWidget {
  const _EventCreateLanguageSelector({
    required this.state,
    this.selectedLabel,
    this.onPressed,
  });

  final _EventCreateLanguageSelectorState state;
  final String? selectedLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fieldLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Язык',
      enText: 'Language',
    );
    final selectorLabel = switch (state) {
      _EventCreateLanguageSelectorState.loading =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Загрузка языков...',
          enText: 'Loading languages...',
        ),
      _EventCreateLanguageSelectorState.error =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Не удалось загрузить языки',
          enText: 'Could not load languages',
        ),
      _EventCreateLanguageSelectorState.selected => selectedLabel ??
          FFLocalizations.of(context).getVariableText(
            ruText: 'Выберите язык',
            enText: 'Choose language',
          ),
    };
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Язык события',
      enText: 'Event language',
    );
    final isEnabled = onPressed != null &&
        state == _EventCreateLanguageSelectorState.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: eventCreateLanguageLabelKey,
          fieldLabel,
          style: ExpatlioDesign.formLabelStyle(context),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Semantics(
          key: eventCreateLanguageSelectorSemanticsKey,
          button: true,
          enabled: isEnabled,
          label: semanticsLabel,
          value: selectorLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: eventCreateLanguageSelectorKey,
              onTap: isEnabled ? onPressed : null,
              borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                ),
                decoration: ExpatlioDesign.cardDecoration(
                  borderColor: ExpatlioDesign.separator,
                  radius: ExpatlioDesign.controlRadius,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.translate_outlined,
                      color: state == _EventCreateLanguageSelectorState.error
                          ? ExpatlioDesign.danger
                          : ExpatlioDesign.primary,
                      size: 20,
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Expanded(
                      child: Text(
                        selectorLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: isEnabled
                              ? ExpatlioDesign.text
                              : ExpatlioDesign.muted,
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    if (state == _EventCreateLanguageSelectorState.loading)
                      Icon(
                        Icons.hourglass_empty,
                        color: ExpatlioDesign.muted,
                        size: 20,
                      )
                    else
                      Icon(
                        FFIcons.kchevronDown,
                        color: isEnabled
                            ? ExpatlioDesign.muted
                            : ExpatlioDesign.disabled,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventCreateLanguageSheet extends StatelessWidget {
  const _EventCreateLanguageSheet({
    required this.catalog,
    required this.selectedLanguageCode,
  });

  final EventLanguageCatalog catalog;
  final String selectedLanguageCode;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      top: false,
      child: Container(
        key: eventCreateLanguageSheetKey,
        decoration: ExpatlioDesign.sheetDecoration(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space20,
                  ExpatlioDesign.space20,
                  ExpatlioDesign.space20,
                  ExpatlioDesign.space12,
                ),
                child: Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Выберите язык',
                    enText: 'Choose language',
                  ),
                  style: ExpatlioDesign.bottomSheetTitleStyle(context),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space8,
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space24,
                  ),
                  itemCount: catalog.languages.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: ExpatlioDesign.space8),
                  itemBuilder: (context, index) {
                    final language = catalog.languages[index];
                    return _EventCreateLanguageOptionTile(
                      language: language,
                      label: _eventCreateLanguageDisplayName(
                        context: context,
                        catalog: catalog,
                        languageCode: language.code,
                      ),
                      selected: language.code == selectedLanguageCode,
                      onTap: () => Navigator.of(context).pop(language.code),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCreateLanguageOptionTile extends StatelessWidget {
  const _EventCreateLanguageOptionTile({
    required this.language,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final EventLanguage language;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: eventCreateLanguageOptionKey(language.code),
          onTap: onTap,
          borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space12,
              ExpatlioDesign.space12,
              ExpatlioDesign.space12,
              ExpatlioDesign.space12,
            ),
            decoration: ExpatlioDesign.cardDecoration(
              borderColor:
                  selected ? ExpatlioDesign.primary : ExpatlioDesign.separator,
              radius: ExpatlioDesign.controlRadius,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 16,
                      weight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.space8),
                if (selected)
                  Icon(
                    Icons.check_circle,
                    color: ExpatlioDesign.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
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

String _eventCreateLanguageDisplayName({
  required BuildContext context,
  required EventLanguageCatalog catalog,
  required String languageCode,
}) {
  return catalog.localizedDisplayName(
    languageCode: languageCode,
    localeCode: FFLocalizations.of(context).languageCode,
  );
}
