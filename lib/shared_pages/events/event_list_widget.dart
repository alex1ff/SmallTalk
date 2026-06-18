import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/events/event_create_widget.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/event_city_catalog.dart';
import '/services/event_city_resolution.dart';
import '/services/event_selected_city_state.dart';

const ValueKey<String> eventListCreateButtonKey =
    ValueKey<String>('event_list_create_button');
const ValueKey<String> eventListCitySelectorKey =
    ValueKey<String>('event_list_city_selector');

class EventListWidget extends StatefulWidget {
  const EventListWidget({
    super.key,
    this.initialSelectedCity,
    this.onCitySelectorPressed,
    this.cityCatalogOverride,
  });

  static String routeName = 'events';
  static String routePath = '/events';

  final EventSelectedCity? initialSelectedCity;
  final VoidCallback? onCitySelectorPressed;
  final EventCityCatalog? cityCatalogOverride;

  @override
  State<EventListWidget> createState() => _EventListWidgetState();
}

class _EventListWidgetState extends State<EventListWidget> {
  late EventSelectedCity? _selectedCity;
  Future<EventCityCatalog>? _cityCatalogFuture;

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.initialSelectedCity;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cityCatalogFuture ??= _loadCityCatalog();
  }

  @override
  void didUpdateWidget(covariant EventListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedCity != widget.initialSelectedCity) {
      _selectedCity = widget.initialSelectedCity;
    }
    if (oldWidget.cityCatalogOverride != widget.cityCatalogOverride) {
      _cityCatalogFuture = _loadCityCatalog();
    }
  }

  Future<EventCityCatalog> _loadCityCatalog() async {
    final override = widget.cityCatalogOverride;
    if (override != null) {
      return override;
    }
    return EventCityCatalog.loadFromAsset(
      bundle: DefaultAssetBundle.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        return FutureBuilder<EventCityCatalog>(
          future: _cityCatalogFuture,
          builder: (context, snapshot) {
            final selectedState = _resolveVisibleSelectedCityState(
              snapshot.data,
            );

            return Scaffold(
              backgroundColor: ExpatlioDesign.background,
              body: SafeArea(
                child: Padding(
                  padding: ExpatlioDesign.pageScrollPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText: 'События',
                                enText: 'Events',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ExpatlioDesign.textStyle(
                                context,
                                size: 34,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: ExpatlioDesign.space16),
                          Tooltip(
                            message:
                                FFLocalizations.of(context).getVariableText(
                              ruText: 'Создать событие',
                              enText: 'Create event',
                            ),
                            child: FlutterFlowIconButton(
                              key: eventListCreateButtonKey,
                              borderColor: Colors.transparent,
                              borderRadius: 24,
                              buttonSize: 48,
                              fillColor: ExpatlioDesign.primary,
                              icon: const Icon(
                                Icons.add_sharp,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () => context.pushNamed(
                                EventCreateWidget.routeName,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: ExpatlioDesign.space16),
                      _EventCitySelector(
                        selectedCity: selectedState?.selected,
                        hasOutdatedProfileCity:
                            selectedState?.hasOutdatedProfileCity ?? false,
                        hasCountryHintOnly: selectedState != null &&
                            selectedState.selected == null &&
                            !selectedState.hasOutdatedProfileCity &&
                            selectedState.countryCodeHint != null,
                        onPressed: widget.onCitySelectorPressed,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  EventSelectedCityState? _resolveVisibleSelectedCityState(
    EventCityCatalog? catalog,
  ) {
    if (_selectedCity != null) {
      return EventSelectedCityState(
        profileStatus: EventCityResolutionStatus.missingProfileCity,
        countryCodeHint: null,
        selected: _selectedCity,
      );
    }
    if (catalog == null) {
      return null;
    }
    return resolveEventSelectedCityState(
      user: currentUserDocument,
      catalog: catalog,
    );
  }
}

class _EventCitySelector extends StatelessWidget {
  const _EventCitySelector({
    required this.selectedCity,
    required this.hasOutdatedProfileCity,
    required this.hasCountryHintOnly,
    required this.onPressed,
  });

  final EventSelectedCity? selectedCity;
  final bool hasOutdatedProfileCity;
  final bool hasCountryHintOnly;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = _citySelectorLabel(context);
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: FFLocalizations.of(context).getVariableText(
        ruText: 'Выбор города',
        enText: 'City selector',
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: eventListCitySelectorKey,
          onTap: onPressed,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: ExpatlioDesign.primary,
                      size: 20,
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: selectedCity == null
                              ? ExpatlioDesign.muted
                              : ExpatlioDesign.text,
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Icon(
                      FFIcons.kchevronDown,
                      color: ExpatlioDesign.muted,
                      size: 20,
                    ),
                  ],
                ),
                if (hasOutdatedProfileCity || hasCountryHintOnly) ...[
                  const SizedBox(height: ExpatlioDesign.space8),
                  Text(
                    _helperText(context),
                    style: ExpatlioDesign.textStyle(
                      context,
                      color: ExpatlioDesign.muted,
                      size: 13,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _citySelectorLabel(BuildContext context) {
    final city = selectedCity?.city;
    if (city == null) {
      if (hasOutdatedProfileCity) {
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Выберите город заново',
          enText: 'Choose city again',
        );
      }
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Выберите город',
        enText: 'Choose city',
      );
    }
    final isRu = FFLocalizations.of(context).languageCode == 'ru';
    final cityName = isRu ? city.cityNameRu : city.cityNameEn;
    return '$cityName · ${city.cityDisplayContext}';
  }

  String _helperText(BuildContext context) {
    if (hasOutdatedProfileCity) {
      return FFLocalizations.of(context).getVariableText(
        ruText:
            'Сохранённый город больше недоступен. Выберите актуальный город, чтобы увидеть события.',
        enText:
            'Your saved city is no longer available. Choose a current city to see events.',
      );
    }
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Выберите город, чтобы увидеть события.',
      enText: 'Choose a city to see events.',
    );
  }
}
