import '/components/language_card_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'lang_model.dart';
export 'lang_model.dart';

class LangWidget extends StatefulWidget {
  const LangWidget({
    super.key,
    required this.action,
    this.selected,
    this.allowedCodes,
    this.items,
    this.expandList = false,
    this.listBottomPadding = 0.0,
  });

  final Future Function(LanguageStruct lang)? action;
  final LanguageStruct? selected;
  final List<String>? allowedCodes;
  final List<LanguageStruct>? items;
  final bool expandList;
  final double listBottomPadding;

  @override
  State<LangWidget> createState() => _LangWidgetState();
}

class _LangWidgetState extends State<LangWidget> {
  late LangModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LangModel());

    _model.searchL2TextController ??= TextEditingController();
    _model.searchL2FocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = FFLocalizations.of(context).languageCode;
    final appStateLanguageRevision = widget.items == null
        ? context.select<FFAppState, int>(
            (appState) => appState.languagesListRevision,
          )
        : null;
    final sourceLanguages =
        widget.items ?? context.read<FFAppState>().languagesList;
    final availableLanguages = _model.availableLanguages(
      sourceLanguages: sourceLanguages,
      sourceSignature: appStateLanguageRevision,
      allowedCodes: widget.allowedCodes,
      selected: widget.selected,
      localeCode: localeCode,
    );
    final resolvedSelectedLanguage = _model.resolveSelectedLanguage(
      languages: availableLanguages,
      selected: widget.selected,
    );
    final query = (_model.searchL2TextController?.text ?? '').trim();
    final languagesToDisplay = query.isNotEmpty
        ? _model.searchLanguages(
            sourceLanguages: sourceLanguages,
            sourceSignature: appStateLanguageRevision,
            allowedCodes: widget.allowedCodes,
            selected: widget.selected,
            localeCode: localeCode,
            query: query,
          )
        : availableLanguages;
    final languagesListView = ListView.separated(
      padding: EdgeInsets.only(bottom: widget.listBottomPadding),
      primary: false,
      shrinkWrap: !widget.expandList,
      physics: widget.expandList
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.vertical,
      itemCount: languagesToDisplay.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: ExpatlioDesign.space8),
      itemBuilder: (context, langIndex) {
        final langItem = languagesToDisplay[langIndex];
        final languageKey =
            '${langItem.code}|${langItem.alternateCodes.join(',')}';
        return LanguageCardWidget(
          key: ValueKey<String>(languageKey),
          lang: langItem,
          currentSelected: resolvedSelectedLanguage,
          callbackAction: (selectedLangData) async {
            await widget.action?.call(
              selectedLangData,
            );
          },
        );
      },
    );

    final searchField = Container(
      width: double.infinity,
      height: 58.0,
      decoration: ExpatlioDesign.cardDecoration(radius: 16.0),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space8,
            ExpatlioDesign.space4,
            ExpatlioDesign.space12,
            ExpatlioDesign.space4),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: 48.0,
              height: 48.0,
              decoration: ExpatlioDesign.softPrimaryDecoration(),
              child: Align(
                alignment: AlignmentDirectional(0.0, 0.0),
                child: Icon(
                  FFIcons.ksearchLg,
                  color: ExpatlioDesign.primary,
                  size: 18.0,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space8,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space8,
                    ExpatlioDesign.space0),
                child: SizedBox(
                  width: 200.0,
                  child: TextFormField(
                    controller: _model.searchL2TextController,
                    focusNode: _model.searchL2FocusNode,
                    onChanged: (_) => safeSetState(() {}),
                    autofocus: false,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    textAlignVertical: TextAlignVertical.center,
                    obscureText: false,
                    decoration: ExpatlioDesign.formFieldDecoration(
                      context,
                      hintText: FFLocalizations.of(context).getText(
                        'fo4zvvcg' /* Поиск */,
                      ),
                      suffixIcon: _model.searchL2TextController!.text.isNotEmpty
                          ? InkWell(
                              onTap: () {
                                _model.searchL2TextController?.clear();
                                safeSetState(() {});
                              },
                              child: const Icon(
                                Icons.clear,
                                color: ExpatlioDesign.muted,
                                size: 16.0,
                              ),
                            )
                          : null,
                    ),
                    style: ExpatlioDesign.formTextStyle(context),
                    cursorColor: ExpatlioDesign.primary,
                    enableInteractiveSelection: true,
                    validator: _model.searchL2TextControllerValidator
                        .asValidator(context),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.expandList) {
      return Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          searchField,
          const SizedBox(height: ExpatlioDesign.space12),
          Expanded(child: languagesListView),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        searchField,
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space12,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
          child: languagesListView,
        ),
      ],
    );
  }
}
