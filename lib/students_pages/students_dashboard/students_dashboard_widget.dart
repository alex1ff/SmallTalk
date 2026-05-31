import '/auth/firebase_auth/auth_util.dart';
import '/components/celebration_s_t_widget.dart';
import '/components/celebration_top_up_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/dashboard_inline_filter_button.dart';
import '/components/orbiting_avatars_cta.dart';
import '/components/profile_dropdown_menu_item.dart';
import '/components/student_availability_switch_control.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/permissions_util.dart';
import '/services/user_match_profile.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/components/no_balance_widget.dart';
import '/components/promo_redeem_widget.dart';
import '/components/fav_widget.dart';
// ─── SUBSCRIPTION REWORK ─ subscription state helpers (hasActiveSubscription,
// formatExpiryDate). Replaces gating by balanceST.
import '/utils/subscription_utils.dart';
import '/components/add_inter_widget.dart';
import '/index.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'students_dashboard_model.dart';
export 'students_dashboard_model.dart';

class StudentsDashboardWidget extends StatefulWidget {
  const StudentsDashboardWidget({
    super.key,
    bool? zn,
    this.done,
    bool? topUpSuccess,
  })  : this.zn = zn ?? false,
        this.topUpSuccess = topUpSuccess ?? false;

  final bool zn;
  final bool? done;
  final bool topUpSuccess;

  static String routeName = 'Students_Dashboard';
  static String routePath = '/studentsDashboard';

  @override
  State<StudentsDashboardWidget> createState() =>
      _StudentsDashboardWidgetState();
}

class _StudentsDashboardWidgetState extends State<StudentsDashboardWidget> {
  late StudentsDashboardModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  String? _partnerCountCacheKey;
  Future<int?>? _partnerCountFuture;
  String? _partnerPreviewCacheKey;
  Future<List<OrbitingAvatarData>>? _partnerPreviewFuture;
  bool _isLocationMenuOpen = false;
  bool _isLevelMenuOpen = false;

  bool get _showLegacyDashboard => false;

  static const _searchAvatarMotion0 = OrbitingAvatarMotionSpec(
    radiusX: 122.0,
    radiusY: 88.0,
    phase: 3.85,
    speed: 1.0,
    drift: 0.16,
    scalePulse: 0.22,
  );
  static const _searchAvatarMotion1 = OrbitingAvatarMotionSpec(
    radiusX: 116.0,
    radiusY: 98.0,
    phase: 5.45,
    speed: -1.0,
    drift: 0.18,
    scalePulse: 0.24,
  );
  static const _searchAvatarMotion2 = OrbitingAvatarMotionSpec(
    radiusX: 142.0,
    radiusY: 86.0,
    phase: 0.14,
    speed: -2.0,
    drift: 0.14,
    scalePulse: 0.18,
  );
  static const _searchAvatarMotion3 = OrbitingAvatarMotionSpec(
    radiusX: 138.0,
    radiusY: 104.0,
    phase: 0.95,
    speed: 1.0,
    drift: 0.17,
    scalePulse: 0.22,
  );
  static const _searchAvatarMotion4 = OrbitingAvatarMotionSpec(
    radiusX: 118.0,
    radiusY: 110.0,
    phase: 2.15,
    speed: 2.0,
    drift: 0.15,
    scalePulse: 0.26,
  );
  static const _searchAvatarMotion5 = OrbitingAvatarMotionSpec(
    radiusX: 110.0,
    radiusY: 106.0,
    phase: 2.95,
    speed: -1.0,
    drift: 0.2,
    scalePulse: 0.24,
  );

  static const _searchAvatarMotions = <OrbitingAvatarMotionSpec>[
    _searchAvatarMotion0,
    _searchAvatarMotion1,
    _searchAvatarMotion2,
    _searchAvatarMotion3,
    _searchAvatarMotion4,
    _searchAvatarMotion5,
  ];

  static const _fallbackSearchAvatars = <OrbitingAvatarData>[
    OrbitingAvatarData(
      initials: 'AK',
      assetPath: 'assets/images/orbiting_avatar_1.jpg',
      size: 40.0,
      motion: _searchAvatarMotion0,
    ),
    OrbitingAvatarData(
      initials: 'MR',
      assetPath: 'assets/images/orbiting_avatar_2.jpg',
      size: 42.0,
      motion: _searchAvatarMotion1,
    ),
    OrbitingAvatarData(
      initials: 'JL',
      assetPath: 'assets/images/orbiting_avatar_3.jpg',
      size: 52.0,
      motion: _searchAvatarMotion2,
    ),
    OrbitingAvatarData(
      initials: 'EL',
      assetPath: 'assets/images/orbiting_avatar_4.jpg',
      size: 44.0,
      motion: _searchAvatarMotion3,
    ),
    OrbitingAvatarData(
      initials: 'KT',
      assetPath: 'assets/images/orbiting_avatar_5.jpg',
      size: 44.0,
      motion: _searchAvatarMotion4,
    ),
    OrbitingAvatarData(
      initials: 'ST',
      assetPath: 'assets/images/orbiting_avatar_6.jpg',
      size: 48.0,
      motion: _searchAvatarMotion5,
    ),
  ];

  bool get _effectiveAvailabilityEnabled =>
      currentUserDocument?.availabilityToday.enabled ?? false;

  bool get _effectiveSwitchValue =>
      _model.switchValue ?? _effectiveAvailabilityEnabled;

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 50.0,
        height: 50.0,
        child: SpinKitCircle(
          color: FlutterFlowTheme.of(context).secondary,
          size: 50.0,
        ),
      ),
    );
  }

  // ─── SUBSCRIPTION REWORK ─ legacy balanceST formatters removed; the
  // dashboard now reads subscription state via subscription_utils.dart. If
  // you need numeric formatting again, prefer `formatNumber` inline.

  Map<String, dynamic> _buildTimezoneMetadataUpdate() {
    final now = DateTime.now();
    return {
      'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      'timezoneName': now.timeZoneName,
      'timezoneUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _syncTimezoneMetadata() async {
    final userRef = currentUserReference;
    if (userRef == null) {
      return;
    }

    try {
      await userRef.update(_buildTimezoneMetadataUpdate());
    } catch (error) {
      debugPrint('StudentsDashboard: failed to sync timezone metadata: $error');
    }
  }

  Future<bool> _openAddInterBottomSheet() async {
    final intervalAdded = await showModalBottomSheet<bool>(
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Padding(
            padding: MediaQuery.viewInsetsOf(context),
            child: AddInterWidget(),
          ),
        );
      },
    );

    if (mounted) {
      safeSetState(() {});
    }
    return intervalAdded ?? false;
  }

  Future<void> _handleAvailabilitySwitchChanged(bool newValue) async {
    final userRef = currentUserReference;
    if (userRef == null) {
      return;
    }

    safeSetState(() => _model.switchValue = newValue);
    if (newValue) {
      if (currentUserDocument!.availabilityToday.intervals.isNotEmpty) {
        final availabilityUpdate = createUsersRecordData(
          availabilityToday: createAvailabilityTodayStruct(
            enabled: true,
            clearUnsetFields: false,
          ),
        );
        availabilityUpdate.addAll(_buildTimezoneMetadataUpdate());
        await userRef.update(availabilityUpdate);
      } else {
        safeSetState(() => _model.switchValue = false);
        final intervalAdded = await _openAddInterBottomSheet();
        if (!mounted) {
          return;
        }

        if (intervalAdded) {
          safeSetState(() => _model.switchValue = true);
        } else {
          final availabilityUpdate = createUsersRecordData(
            availabilityToday: createAvailabilityTodayStruct(
              enabled: false,
              clearUnsetFields: false,
            ),
          );
          availabilityUpdate.addAll(_buildTimezoneMetadataUpdate());
          await userRef.update(availabilityUpdate);
          if (mounted) {
            safeSetState(() => _model.switchValue = false);
          }
        }
      }
      if (mounted) {
        safeSetState(() {});
      }
    } else {
      final availabilityUpdate = createUsersRecordData(
        availabilityToday: createAvailabilityTodayStruct(
          enabled: false,
          clearUnsetFields: false,
        ),
      );
      availabilityUpdate.addAll(_buildTimezoneMetadataUpdate());
      await userRef.update(availabilityUpdate);
      if (mounted) {
        safeSetState(() {});
      }
    }
  }

  Widget _buildAvailabilitySwitch() {
    return StudentAvailabilitySwitchControl(
      value: _effectiveSwitchValue,
      onChanged: (newValue) async {
        await _handleAvailabilitySwitchChanged(newValue);
      },
    );
  }

  String _localizedText({
    required BuildContext context,
    required String ruText,
    required String enText,
  }) {
    return FFLocalizations.of(context).getVariableText(
      ruText: ruText,
      enText: enText,
    );
  }

  bool _hasCountryData(CountryStruct? country) {
    if (country == null) {
      return false;
    }

    return country.code.trim().isNotEmpty;
  }

  CountryStruct? _preferredLocation(UsersRecord? user) {
    if (user == null || !user.preferences.hasPreferredLocation()) {
      return null;
    }

    final preferredLocation = user.preferences.preferredLocation;
    return _hasCountryData(preferredLocation) ? preferredLocation : null;
  }

  String _preferredLocationLabel(BuildContext context, CountryStruct? country) {
    if (!_hasCountryData(country)) {
      return _localizedText(
        context: context,
        ruText: 'Любая',
        enText: 'Any',
      );
    }

    final isRu = FFLocalizations.of(context).languageCode == 'ru';
    final localizedName = isRu ? country!.nameRu : country!.nameEn;
    if (localizedName.trim().isNotEmpty) {
      return localizedName;
    }

    final fallbackName = isRu ? country.nameEn : country.nameRu;
    if (fallbackName.trim().isNotEmpty) {
      return fallbackName;
    }

    return country.code.toUpperCase();
  }

  String _levelShortLabel(Level level) {
    switch (level) {
      case Level.Beginner:
        return 'A1';
      case Level.Basic:
        return 'A2';
      case Level.Intermediate:
        return 'B1';
      case Level.Fluent:
        return 'C1';
    }
  }

  String _defaultPartnerLevelLabel(BuildContext context, UsersRecord? user) {
    final currentUserLevel = resolveUserMatchLevel(user);
    if (currentUserLevel == null) {
      return _localizedText(
        context: context,
        ruText: 'Любой',
        enText: 'Any',
      );
    }

    return _levelShortLabel(currentUserLevel);
  }

  Future<void> _clearPreferredLocation() async {
    final userRef = currentUserReference;
    if (userRef == null) {
      return;
    }

    await userRef.update(
      createUsersRecordData(
        preferences: createPreferencesStruct(
          fieldValues: {
            'preferredLocation': FieldValue.delete(),
          },
          clearUnsetFields: false,
        ),
      ),
    );
  }

  Future<void> _setPreferredPartnerLevel(Level? level) async {
    final userRef = currentUserReference;
    if (userRef == null) {
      return;
    }

    await userRef.update(
      createUsersRecordData(
        preferences: level == null
            ? createPreferencesStruct(
                fieldValues: {
                  'preferredPartnerLevel': FieldValue.delete(),
                },
                clearUnsetFields: false,
              )
            : createPreferencesStruct(
                preferredPartnerLevel: level,
                clearUnsetFields: false,
              ),
      ),
    );
  }

  List<CountryStruct> _locationDropdownCountries() {
    final countries = functions.countriesList();
    return countries.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
  }

  String _levelDropdownLabel(Level level) {
    switch (level) {
      case Level.Beginner:
        return 'A1 — Beginner';
      case Level.Basic:
        return 'A2 — Basic';
      case Level.Intermediate:
        return 'B1 — Intermediate';
      case Level.Fluent:
        return 'C1 — Fluent';
    }
  }

  Future<void> _openPreferredPartnerLevelPicker(
    BuildContext anchorContext,
  ) async {
    const anyLevelValue = '__any__';
    final currentPartnerLevel =
        currentUserDocument?.preferences.preferredPartnerLevel;
    safeSetState(() => _isLevelMenuOpen = true);
    final selectedValue = await _showDashboardOptionsMenu<String>(
      anchorContext,
      options: [
        for (final level in Level.values)
          _DashboardMenuOption<String>(
            value: level.name,
            label: _levelDropdownLabel(level),
            selected: level == currentPartnerLevel,
          ),
        _DashboardMenuOption<String>(
          value: anyLevelValue,
          label: _localizedText(
            context: context,
            ruText: 'Любой',
            enText: 'Any',
          ),
          selected: currentPartnerLevel == null,
        ),
      ],
    );
    if (mounted) {
      safeSetState(() => _isLevelMenuOpen = false);
    }

    if (!mounted || selectedValue == null) {
      return;
    }

    final livePreferredPartnerLevel =
        currentUserDocument?.preferences.preferredPartnerLevel;
    if (selectedValue == anyLevelValue) {
      if (livePreferredPartnerLevel != null) {
        await _setPreferredPartnerLevel(null);
      }
      safeSetState(() {});
      return;
    }

    final selectedLevel = Level.values.firstWhere(
      (level) => level.name == selectedValue,
      orElse: () => livePreferredPartnerLevel ?? Level.Basic,
    );
    if (selectedLevel == livePreferredPartnerLevel) {
      safeSetState(() {});
      return;
    }

    await _setPreferredPartnerLevel(selectedLevel);
    safeSetState(() {});
  }

  Future<void> _openPreferredLocationPicker(
    BuildContext anchorContext,
  ) async {
    if (!mounted) {
      return;
    }

    final countries = _locationDropdownCountries();
    final anyLocationLabel = _localizedText(
      context: context,
      ruText: 'Любая',
      enText: 'Any',
    );
    final currentLocation = _preferredLocation(currentUserDocument);
    safeSetState(() => _isLocationMenuOpen = true);
    final selectedCode = await _showDashboardOptionsMenu<String>(
      anchorContext,
      options: [
        for (final country in countries)
          _DashboardMenuOption<String>(
            value: country.code,
            label: _preferredLocationLabel(context, country),
            selected: country.code == currentLocation?.code,
          ),
        _DashboardMenuOption<String>(
          value: '',
          label: anyLocationLabel,
          selected: currentLocation == null,
        ),
      ],
    );
    if (mounted) {
      safeSetState(() => _isLocationMenuOpen = false);
    }

    if (!mounted || selectedCode == null) {
      return;
    }

    final livePreferredLocation = _preferredLocation(currentUserDocument);
    if (selectedCode.isEmpty) {
      if (livePreferredLocation != null) {
        await _clearPreferredLocation();
      }
      safeSetState(() {});
      return;
    }

    if (selectedCode == livePreferredLocation?.code) {
      safeSetState(() {});
      return;
    }

    final selectedCountry = countries.firstWhere(
      (country) => country.code == selectedCode,
    );

    await currentUserReference!.update(
      createUsersRecordData(
        preferences: createPreferencesStruct(
          preferredLocation: updateCountryStruct(
            selectedCountry,
            clearUnsetFields: false,
          ),
          clearUnsetFields: false,
        ),
      ),
    );

    safeSetState(() {});
  }

  Future<T?> _showDashboardOptionsMenu<T>(
    BuildContext anchorContext, {
    required List<_DashboardMenuOption<T>> options,
  }) {
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;

    if (anchorBox == null || overlayBox == null || !anchorBox.attached) {
      return Future<T?>.value(null);
    }

    const viewportMargin = 16.0;
    const minMenuWidth = 206.0;
    const preferredMenuWidth = 280.0;
    final anchorOffset =
        anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final availableMenuWidth =
        math.max(0.0, overlayBox.size.width - (viewportMargin * 2));
    final menuWidth = math.max(
      math.min(minMenuWidth, availableMenuWidth),
      math.min(preferredMenuWidth, availableMenuWidth),
    );
    final maxMenuLeft = math.max(
        viewportMargin, overlayBox.size.width - menuWidth - viewportMargin);
    final menuLeft = (anchorOffset.dx + anchorBox.size.width - menuWidth)
        .clamp(viewportMargin, maxMenuLeft)
        .toDouble();
    final anchorRect = Rect.fromLTWH(
      menuLeft,
      anchorOffset.dy + anchorBox.size.height + 8.0,
      menuWidth,
      0.0,
    );

    return showMenu<T>(
      context: anchorContext,
      position:
          RelativeRect.fromRect(anchorRect, Offset.zero & overlayBox.size),
      color: ExpatlioDesign.card,
      elevation: 8.0,
      shadowColor: const Color(0x12000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: ExpatlioDesign.border),
      ),
      clipBehavior: Clip.antiAlias,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
      ),
      items: [
        for (final option in options)
          PopupMenuItem<T>(
            value: option.value,
            height: 42.0,
            padding: EdgeInsets.zero,
            child: ProfileDropdownMenuItem(
              label: option.label,
              selected: option.selected,
            ),
          ),
      ],
    );
  }

  Query<Map<String, dynamic>> _filteredPartnerProfilesQuery({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) {
    final activeLanguage =
        resolveUserActiveConversationLanguage(currentUserDocument);
    final preferredCountryCode = preferredLocation?.code.trim();

    var query = FirebaseFirestore.instance
        .collection('userPublicProfiles')
        .where('role', isEqualTo: UserRole.native_speaker.serialize())
        .where('isProfileComplete', isEqualTo: true);

    if (activeLanguage != null && activeLanguage.isNotEmpty) {
      query = query.where(
        'language_instruction_NS.code',
        isEqualTo: activeLanguage,
      );
    }
    if (preferredCountryCode != null && preferredCountryCode.isNotEmpty) {
      query = query.where(
        'Country_NS.code',
        isEqualTo: preferredCountryCode,
      );
    }
    if (preferredPartnerLevel != null) {
      query = query.where(
        'level',
        isEqualTo: preferredPartnerLevel.serialize(),
      );
    }

    return query;
  }

  Future<int?> _loadFilteredPartnerCount({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) async {
    try {
      final query = _filteredPartnerProfilesQuery(
        preferredLocation: preferredLocation,
        preferredPartnerLevel: preferredPartnerLevel,
      );
      final countSnapshot = await query.count().get();
      return countSnapshot.count;
    } catch (error) {
      debugPrint('StudentsDashboard: failed to load partner count: $error');
      return null;
    }
  }

  Future<List<OrbitingAvatarData>> _loadFilteredPartnerPreviewAvatars({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) async {
    try {
      final snapshot = await _filteredPartnerProfilesQuery(
        preferredLocation: preferredLocation,
        preferredPartnerLevel: preferredPartnerLevel,
      ).limit(_searchAvatarMotions.length).get();

      final profiles = snapshot.docs
          .map(UserPublicProfilesRecord.fromSnapshot)
          .toList(growable: false);

      return _buildPartnerPreviewAvatars(profiles);
    } catch (error) {
      debugPrint('StudentsDashboard: failed to load partner avatars: $error');
      return _fallbackSearchAvatars;
    }
  }

  Future<int?> _partnerCountFutureFor({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) {
    final activeLanguage =
        resolveUserActiveConversationLanguage(currentUserDocument) ?? '';
    final cacheKey = [
      activeLanguage,
      preferredLocation?.code ?? '',
      preferredPartnerLevel?.name ?? '',
    ].join('|');

    if (_partnerCountCacheKey != cacheKey || _partnerCountFuture == null) {
      _partnerCountCacheKey = cacheKey;
      _partnerCountFuture = _loadFilteredPartnerCount(
        preferredLocation: preferredLocation,
        preferredPartnerLevel: preferredPartnerLevel,
      );
    }

    return _partnerCountFuture!;
  }

  Future<List<OrbitingAvatarData>> _partnerPreviewFutureFor({
    required CountryStruct? preferredLocation,
    required Level? preferredPartnerLevel,
  }) {
    final activeLanguage =
        resolveUserActiveConversationLanguage(currentUserDocument) ?? '';
    final cacheKey = [
      activeLanguage,
      preferredLocation?.code ?? '',
      preferredPartnerLevel?.name ?? '',
    ].join('|');

    if (_partnerPreviewCacheKey != cacheKey || _partnerPreviewFuture == null) {
      _partnerPreviewCacheKey = cacheKey;
      _partnerPreviewFuture = _loadFilteredPartnerPreviewAvatars(
        preferredLocation: preferredLocation,
        preferredPartnerLevel: preferredPartnerLevel,
      );
    }

    return _partnerPreviewFuture!;
  }

  List<OrbitingAvatarData> _buildPartnerPreviewAvatars(
    List<UserPublicProfilesRecord> profiles,
  ) {
    final avatars = <OrbitingAvatarData>[];
    final maxCount = math.min(profiles.length, _searchAvatarMotions.length);

    for (var i = 0; i < maxCount; i++) {
      final profile = profiles[i];
      final photoUrl = profile.photoUrl.trim();
      avatars.add(
        OrbitingAvatarData(
          initials: _avatarInitials(profile.displayName, i),
          assetPath:
              photoUrl.isEmpty ? _fallbackSearchAvatars[i].assetPath : '',
          photoUrl: photoUrl,
          size: _fallbackSearchAvatars[i].size,
          motion: _searchAvatarMotions[i],
        ),
      );
    }

    for (var i = avatars.length; i < _fallbackSearchAvatars.length; i++) {
      avatars.add(_fallbackSearchAvatars[i]);
    }

    return avatars;
  }

  String _avatarInitials(String displayName, int index) {
    final nameParts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    if (nameParts.isNotEmpty) {
      final name = nameParts.first;
      return name.length >= 2
          ? name.substring(0, 2).toUpperCase()
          : name[0].toUpperCase();
    }

    return _fallbackSearchAvatars[index % _fallbackSearchAvatars.length]
        .initials;
  }

  String _partnerCountNoun(BuildContext context, int count) {
    if (FFLocalizations.of(context).languageCode != 'ru') {
      return count == 1 ? 'person' : 'people';
    }

    final lastTwo = count % 100;
    if (lastTwo >= 11 && lastTwo <= 14) {
      return 'человек';
    }

    switch (count % 10) {
      case 1:
        return 'человек';
      case 2:
      case 3:
      case 4:
        return 'человека';
      default:
        return 'человек';
    }
  }

  Widget _buildAvailabilitySection(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 60.0,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryBackground,
              borderRadius: BorderRadius.circular(26.0),
            ),
            child: Padding(
              padding: ExpatlioDesign.cardPadding,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    FFLocalizations.of(context).getText(
                      'n1zbzn9y' /* Доступен сегодня */,
                    ),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          color: FlutterFlowTheme.of(context).primaryText,
                          fontSize: 16.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.normal,
                        ),
                  ),
                  _buildAvailabilitySwitch(),
                ],
              ),
            ),
          ),
          if (_effectiveAvailabilityEnabled) ...[
            const SizedBox(height: ExpatlioDesign.compactSpacing),
            Builder(
              builder: (context) {
                final intervals =
                    currentUserDocument?.availabilityToday.intervals.toList() ??
                        [];

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  primary: false,
                  shrinkWrap: true,
                  scrollDirection: Axis.vertical,
                  itemCount: intervals.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: ExpatlioDesign.compactSpacing),
                  itemBuilder: (context, intervalsIndex) {
                    final intervalsItem = intervals[intervalsIndex];
                    return Container(
                      width: double.infinity,
                      height: 60.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(26.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              width: 52.0,
                              height: 52.0,
                              decoration: BoxDecoration(
                                color: ExpatlioDesign.mutedSurface,
                                borderRadius: BorderRadius.circular(22.0),
                              ),
                              child: Align(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Icon(
                                  FFIcons.kclock,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 20.0,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    12.0, 0.0, 0.0, 0.0),
                                child: Text(
                                  '${intervalsItem.start} - ${intervalsItem.end}',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        fontSize: 16.0,
                                        letterSpacing: 0.0,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            FlutterFlowIconButton(
                              borderRadius: 22.0,
                              buttonSize: 52.0,
                              icon: Icon(
                                FFIcons.ktrash03,
                                color: FlutterFlowTheme.of(context).error,
                                size: 18.0,
                              ),
                              onPressed: () async {
                                final userRef = currentUserReference;
                                if (userRef == null) {
                                  return;
                                }

                                await userRef.update(createUsersRecordData(
                                  availabilityToday:
                                      createAvailabilityTodayStruct(
                                    fieldValues: {
                                      'intervals': FieldValue.arrayRemove([
                                        getIntervalsFirestoreData(
                                          updateIntervalsStruct(
                                            intervalsItem,
                                            clearUnsetFields: false,
                                          ),
                                          true,
                                        )
                                      ]),
                                    },
                                    clearUnsetFields: false,
                                  ),
                                ));
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: ExpatlioDesign.compactSpacing),
            InkWell(
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () async {
                await _openAddInterBottomSheet();
              },
              child: Container(
                width: double.infinity,
                height: 60.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  borderRadius: BorderRadius.circular(26.0),
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FlutterFlowIconButton(
                        borderRadius: 12.0,
                        buttonSize: 35.0,
                        fillColor:
                            FlutterFlowTheme.of(context).secondaryBackground,
                        icon: Icon(
                          Icons.add_sharp,
                          color: FlutterFlowTheme.of(context).primaryText,
                          size: 18.0,
                        ),
                        onPressed: () async {
                          await _openAddInterBottomSheet();
                        },
                      ),
                      Text(
                        FFLocalizations.of(context).getText(
                          'ws9tu06c' /* Добавить интервал */,
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              color: FlutterFlowTheme.of(context).primaryText,
                              fontSize: 15.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ].divide(
                      const SizedBox(width: ExpatlioDesign.compactSpacing),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleStartConversation() async {
    if (!hasActiveSubscription(currentUserDocument)) {
      await showModalBottomSheet(
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        context: context,
        builder: (context) {
          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Padding(
              padding: MediaQuery.viewInsetsOf(context),
              child: NoBalanceWidget(),
            ),
          );
        },
      ).then((value) => safeSetState(() {}));
      return;
    }

    if (!(await ensureCameraAndMicrophonePermissions())) {
      return;
    }

    if (!mounted) {
      return;
    }
    context.pushNamed(WaitingForTeacherPageWidget.routeName);
  }

  Widget _buildSearchCtaContent({
    required BuildContext context,
    required List<OrbitingAvatarData> avatars,
    required CountryStruct? preferredLocation,
    required Level? selectedPartnerLevel,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final orbitHeight =
            (constraints.maxHeight - 50.0).clamp(250.0, 320.0).toDouble();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: orbitHeight,
              child: OrbitingAvatarsCta(
                avatars: avatars,
                action: _buildStartSearchButton(context),
              ),
            ),
            const SizedBox(height: ExpatlioDesign.itemSpacing),
            _buildPartnerCountText(
              context: context,
              preferredLocation: preferredLocation,
              selectedPartnerLevel: selectedPartnerLevel,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStartSearchButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20.0),
        onTap: _handleStartConversation,
        child: Container(
          width: 240.0,
          height: 60.0,
          decoration: BoxDecoration(
            gradient: ExpatlioDesign.primaryGradient,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x267430E8),
                blurRadius: 22.0,
                offset: Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 22.0,
              ),
              const SizedBox(width: ExpatlioDesign.itemSpacing),
              Text(
                FFLocalizations.of(context).getVariableText(
                  ruText: 'Начать поиск',
                  enText: 'Start search',
                ),
                style: ExpatlioDesign.textStyle(
                  context,
                  color: Colors.white,
                  size: 18.0,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerCountText({
    required BuildContext context,
    required CountryStruct? preferredLocation,
    required Level? selectedPartnerLevel,
  }) {
    return FutureBuilder<int?>(
      future: _partnerCountFutureFor(
        preferredLocation: preferredLocation,
        preferredPartnerLevel: selectedPartnerLevel,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'считаем людей рядом',
              enText: 'counting nearby people',
            ),
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.muted,
              size: 13.0,
              weight: FontWeight.w400,
            ),
          );
        }

        final count = snapshot.data;
        if (count == null) {
          return Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'количество людей недоступно',
              enText: 'people count unavailable',
            ),
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.muted,
              size: 13.0,
              weight: FontWeight.w400,
            ),
          );
        }

        return RichText(
          textScaler: MediaQuery.of(context).textScaler,
          text: TextSpan(
            children: [
              TextSpan(
                text: FFLocalizations.of(context).getVariableText(
                  ruText: 'рядом с вами ',
                  enText: 'near you ',
                ),
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.muted,
                  size: 13.0,
                  weight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: count.toString(),
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.success,
                  size: 13.0,
                  weight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: ' ${_partnerCountNoun(context, count)}',
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.muted,
                  size: 13.0,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReferenceSearchHero(BuildContext context) {
    final selectedPartnerLevel =
        currentUserDocument?.preferences.preferredPartnerLevel;
    final preferredLocation = _preferredLocation(currentUserDocument);
    final heroHeight =
        (MediaQuery.sizeOf(context).height - 190.0).clamp(560.0, 760.0);

    return SizedBox(
      height: heroHeight.toDouble(),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.pagePadding,
          0.0,
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.pagePaddingLarge,
        ),
        child: Column(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 246.0,
              height: 72.0,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 30.0),
            _buildAvailabilitySection(context),
            const SizedBox(height: ExpatlioDesign.itemSpacing),
            Row(
              children: [
                Expanded(
                  child: DashboardInlineFilterButton(
                    title: preferredLocation == null
                        ? _localizedText(
                            context: context,
                            ruText: 'Локация',
                            enText: 'Location',
                          )
                        : '',
                    label: preferredLocation == null
                        ? ''
                        : _preferredLocationLabel(
                            context,
                            preferredLocation,
                          ),
                    selected: preferredLocation != null,
                    icon: Icons.location_on_outlined,
                    menuOpen: _isLocationMenuOpen,
                    onTap: _openPreferredLocationPicker,
                    onClear: preferredLocation == null
                        ? null
                        : () async {
                            await _clearPreferredLocation();
                            safeSetState(() {});
                          },
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.itemSpacing),
                Expanded(
                  child: DashboardInlineFilterButton(
                    title: _localizedText(
                      context: context,
                      ruText: 'Уровень',
                      enText: 'Level',
                    ),
                    label: selectedPartnerLevel == null
                        ? ''
                        : _levelShortLabel(selectedPartnerLevel),
                    selected: selectedPartnerLevel != null,
                    icon: Icons.school_outlined,
                    menuOpen: _isLevelMenuOpen,
                    onTap: _openPreferredPartnerLevelPicker,
                    onClear: selectedPartnerLevel == null
                        ? null
                        : () async {
                            await _setPreferredPartnerLevel(null);
                            safeSetState(() {});
                          },
                  ),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<OrbitingAvatarData>>(
                future: _partnerPreviewFutureFor(
                  preferredLocation: preferredLocation,
                  preferredPartnerLevel: selectedPartnerLevel,
                ),
                initialData: _fallbackSearchAvatars,
                builder: (context, snapshot) {
                  final avatars = snapshot.data?.isNotEmpty == true
                      ? snapshot.data!
                      : _fallbackSearchAvatars;

                  return _buildSearchCtaContent(
                    context: context,
                    avatars: avatars,
                    preferredLocation: preferredLocation,
                    selectedPartnerLevel: selectedPartnerLevel,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StudentsDashboardModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      unawaited(_syncTimezoneMetadata());
      if (widget.topUpSuccess) {
        await showModalBottomSheet(
          useRootNavigator: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          context: context,
          builder: (context) {
            return GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: Padding(
                padding: MediaQuery.viewInsetsOf(context),
                child: CelebrationTopUpWidget(),
              ),
            );
          },
        ).then((value) => safeSetState(() {}));
      } else if (widget.zn) {
        await showModalBottomSheet(
          useRootNavigator: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          context: context,
          builder: (context) {
            return GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: Padding(
                padding: MediaQuery.viewInsetsOf(context),
                child: CelebrationSTWidget(
                  done: widget.done ?? false,
                ),
              ),
            );
          },
        ).then((value) => safeSetState(() {}));
      }
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: AuthUserStreamWidget(
          builder: (context) {
            if (currentUserUid.isEmpty || currentUserDocument == null) {
              return _buildLoadingState(context);
            }

            return Stack(
              children: [
                SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReferenceSearchHero(context),
                      if (_showLegacyDashboard) ...[
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
                          child: Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(2),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Container(
                                    width: 66,
                                    height: 66,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        width: 1,
                                      ),
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        if (currentUserPhoto != '') {
                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(100),
                                            child: CachedNetworkImage(
                                              fadeInDuration:
                                                  Duration(milliseconds: 0),
                                              fadeOutDuration:
                                                  Duration(milliseconds: 0),
                                              imageUrl: currentUserPhoto,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                              memCacheWidth: 132,
                                              memCacheHeight: 132,
                                            ),
                                          );
                                        } else {
                                          return Align(
                                            alignment:
                                                AlignmentDirectional(0, 0),
                                            child: AuthUserStreamWidget(
                                              builder: (context) {
                                                final displayName =
                                                    currentUserDisplayName
                                                        .trim();
                                                final firstLetter =
                                                    displayName.isNotEmpty
                                                        ? displayName[0]
                                                            .toUpperCase()
                                                        : '?';
                                                return Text(
                                                  firstLetter,
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        fontSize: 24,
                                                        letterSpacing: 0.0,
                                                      ),
                                                );
                                              },
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          12, 0, 0, 0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AuthUserStreamWidget(
                                            builder: (context) => Text(
                                              'Привет, ${currentUserDisplayName}',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 15,
                                                        letterSpacing: 0.0,
                                                      ),
                                            ),
                                          ),
                                          Text(
                                            FFLocalizations.of(context).getText(
                                              'xocrym2z' /* Welcome to Expatlio */,
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  fontSize: 16,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(6, 6, 6, 0),
                          child: InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              context.pushNamed(PayWidget.routeName);
                            },
                            child: Stack(
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      55, 0, 55, 0),
                                  child: Container(
                                    width: double.infinity,
                                    height: 165,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Color(0xFFE0E3E7),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Image.asset(
                                      'assets/images/Group_1171275327_2.png',
                                      width: 65,
                                      fit: BoxFit.contain,
                                    ),
                                    Image.asset(
                                      'assets/images/Group_1171275327_1.png',
                                      width: 65,
                                      fit: BoxFit.contain,
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ─── SUBSCRIPTION REWORK ─────────
                                      // Was: "Текущий баланс" + "~ X минут".
                                      // Now: "Подписка" + active/expired hint.
                                      Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Подписка',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  fontSize: 15,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                          ),
                                          AuthUserStreamWidget(
                                            builder: (context) {
                                              final user = currentUserDocument;
                                              final active =
                                                  hasActiveSubscription(user);
                                              final hasGift =
                                                  hasUsableGiftMinutes(user);
                                              final String label;
                                              final bool highlight;
                                              if (active) {
                                                label = 'Активна';
                                                highlight = true;
                                              } else if (hasGift) {
                                                label = 'Подарок';
                                                highlight = true;
                                              } else {
                                                label = 'Не активна';
                                                highlight = false;
                                              }
                                              return Text(
                                                label,
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      fontFamily:
                                                          'sf pro display',
                                                      color: highlight
                                                          ? FlutterFlowTheme.of(
                                                                  context)
                                                              .primary
                                                          : FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      fontSize: 15,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      // ────────────────────────────────────
                                      // ─── SUBSCRIPTION REWORK ─────────
                                      // Was: big Expatlio counter.
                                      // Now: subscription expiry date or
                                      // "Нет активной подписки" copy.
                                      AuthUserStreamWidget(
                                        builder: (context) {
                                          final user = currentUserDocument;
                                          final active =
                                              hasActiveSubscription(user);
                                          final expires =
                                              subscriptionExpiresAt(user);
                                          if (active && expires != null) {
                                            return RichText(
                                              textScaler: MediaQuery.of(context)
                                                  .textScaler,
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'до ',
                                                    style: TextStyle(
                                                      fontFamily: 'Cool',
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      fontWeight:
                                                          FontWeight.w300,
                                                      fontSize: 24,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: formatExpiryDate(
                                                        expires),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 40,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w300,
                                                        ),
                                                  ),
                                                ],
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily: 'Cool',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 40,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                        ),
                                              ),
                                            );
                                          }
                                          // Fallback: no subscription. Show
                                          // the unexpired gift bucket if any,
                                          // else "Нет активной подписки".
                                          final giftMinutes =
                                              remainingGiftMinutes(user);
                                          final giftExpiresAt =
                                              giftMinutesExpiresAt(user);
                                          if (giftMinutes > 0 &&
                                              giftExpiresAt != null) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${formatGiftMinutes(giftMinutes)} мин в подарок',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primary,
                                                        fontSize: 28,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'действуют ${formatGiftExpiry(giftExpiresAt)}',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 14,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                              ],
                                            );
                                          }
                                          return Text(
                                            'Нет активной подписки',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  fontSize: 24,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                          );
                                        },
                                      ),
                                      // ────────────────────────────────────
                                      // ─── SUBSCRIPTION REWORK ─ promo CTA
                                      // Always visible so the user can top
                                      // up gift minutes any time.
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0, 12, 0, 0),
                                        child: TextButton(
                                          onPressed: () async {
                                            await showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (_) =>
                                                  const PromoRedeemWidget(),
                                            );
                                            safeSetState(() {});
                                          },
                                          child: Text(
                                            'У меня есть промокод',
                                            style: FlutterFlowTheme.of(context)
                                                .titleSmall
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                  fontSize: 14,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                      ),
                                      // ────────────────────────────────────
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0, 22, 0, 0),
                                        child: Container(
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(100),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.all(2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(16, 0, 12, 0),
                                                  child: Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      'nes89ax1' /* Пополнить */,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 16,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                  ),
                                                ),
                                                Container(
                                                  width: 41,
                                                  height: 41,
                                                  decoration: BoxDecoration(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Align(
                                                    alignment:
                                                        AlignmentDirectional(
                                                            0, 0),
                                                    child: Icon(
                                                      FFIcons.kchevronRight,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      size: 18,
                                                    ),
                                                  ),
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
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(6, 10, 6, 0),
                          child: AuthUserStreamWidget(
                            builder: (context) {
                              final selectedPartnerLevel = currentUserDocument
                                  ?.preferences.preferredPartnerLevel;
                              final preferredLocation =
                                  _preferredLocation(currentUserDocument);

                              return Row(
                                children: [
                                  Expanded(
                                    child: DashboardInlineFilterButton(
                                      title: preferredLocation == null
                                          ? _localizedText(
                                              context: context,
                                              ruText: 'Локация',
                                              enText: 'Location',
                                            )
                                          : '',
                                      label: preferredLocation == null
                                          ? ''
                                          : _preferredLocationLabel(
                                              context,
                                              preferredLocation,
                                            ),
                                      selected: preferredLocation != null,
                                      icon: Icons.public_rounded,
                                      onTap: _openPreferredLocationPicker,
                                      onClear: preferredLocation == null
                                          ? null
                                          : () async {
                                              await _clearPreferredLocation();
                                              safeSetState(() {});
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: DashboardInlineFilterButton(
                                      title: _localizedText(
                                        context: context,
                                        ruText: 'Уровень',
                                        enText: 'Level',
                                      ),
                                      label: selectedPartnerLevel == null
                                          ? _defaultPartnerLevelLabel(
                                              context,
                                              currentUserDocument,
                                            )
                                          : _levelShortLabel(
                                              selectedPartnerLevel,
                                            ),
                                      selected: selectedPartnerLevel != null,
                                      icon: Icons.tune_rounded,
                                      onTap: _openPreferredPartnerLevelPicker,
                                      onClear: selectedPartnerLevel == null
                                          ? null
                                          : () async {
                                              await _setPreferredPartnerLevel(
                                                null,
                                              );
                                              safeSetState(() {});
                                            },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(6, 8, 6, 0),
                          child: _buildAvailabilitySection(context),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(0, 40, 0, 0),
                          child: Stack(
                            alignment: AlignmentDirectional(0, -1),
                            children: [
                              Image.asset(
                                'assets/images/group_11712750962.webp',
                                width: double.infinity,
                                height: 294.27,
                                fit: BoxFit.contain,
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    60, 110, 60, 0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      FFLocalizations.of(context).getText(
                                        'a3nqo0ec' /* Найди собеседника
для практики */
                                        ,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            fontSize: 21,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0, 10, 0, 0),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'crtk35jr' /* Первая минута бесплатно! */,
                                        ),
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 15,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0, 29, 0, 0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          // ─── SUBSCRIPTION REWORK ────
                                          // Gate by active subscription
                                          // instead of legacy balanceST.
                                          if (!hasActiveSubscription(
                                              currentUserDocument)) {
                                            // ──────────────────────────
                                            await showModalBottomSheet(
                                              useRootNavigator: true,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              context: context,
                                              builder: (context) {
                                                return GestureDetector(
                                                  onTap: () {
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        MediaQuery.viewInsetsOf(
                                                            context),
                                                    child: NoBalanceWidget(),
                                                  ),
                                                );
                                              },
                                            ).then(
                                                (value) => safeSetState(() {}));
                                            return;
                                          }

                                          if (!(await ensureCameraAndMicrophonePermissions())) {
                                            return;
                                          }

                                          if (!mounted) {
                                            return;
                                          }
                                          context.pushNamed(
                                              WaitingForTeacherPageWidget
                                                  .routeName);
                                        },
                                        child: Container(
                                          width: 233.9,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            gradient:
                                                ExpatlioDesign.primaryGradient,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x227430E8),
                                                blurRadius: 18,
                                                offset: Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(20, 0, 20, 0),
                                              child: Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'flmz1vkr' /* Начать разговор */,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: Colors.white,
                                                          fontSize: 17,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w700,
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
                            ],
                          ),
                        ),
                        if (resolveFriendsForUser(currentUserDocument)
                            .isNotEmpty)
                          Padding(
                            padding:
                                EdgeInsetsDirectional.fromSTEB(0, 30, 0, 0),
                            child: AuthUserStreamWidget(
                              builder: (context) => Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      context
                                          .pushNamed(FavoriteWidget.routeName);
                                    },
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16, 0, 16, 0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              FFLocalizations.of(context)
                                                  .getText(
                                                'a4u0etcs' /* Друзья */,
                                              ),
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        fontSize: 21,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                      ),
                                            ),
                                            Icon(
                                              FFIcons.kchevronRight,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0, 10, 0, 0),
                                    child: Container(
                                      width: double.infinity,
                                      height: 180,
                                      decoration: BoxDecoration(),
                                      child: Builder(
                                        builder: (context) {
                                          final favs = resolveFriendsForUser(
                                                  currentUserDocument)
                                              .toList();

                                          return ListView.separated(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 6),
                                            scrollDirection: Axis.horizontal,
                                            itemCount: favs.length,
                                            separatorBuilder: (_, __) =>
                                                SizedBox(width: 6),
                                            itemBuilder: (context, favsIndex) {
                                              final favsItem = favs[favsIndex];
                                              return FavWidget(
                                                key: Key(
                                                    'Keyy7d_${favsIndex}_of_${favs.length}'),
                                                nsUser: favsItem,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(16, 40, 0, 0),
                          child: Text(
                            FFLocalizations.of(context).getText(
                              'lffx4k7x' /* Статистика за сегодня */,
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  fontSize: 21,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(6, 10, 6, 0),
                          child: StreamBuilder<List<StatsRecord>>(
                            stream: _model.statsStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return const SizedBox.shrink();
                              }
                              if (!snapshot.hasData) {
                                return Center(
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: SpinKitCircle(
                                      color: FlutterFlowTheme.of(context)
                                          .secondary,
                                      size: 50,
                                    ),
                                  ),
                                );
                              }
                              List<StatsRecord>
                                  conditionalBuilderStatsRecordList =
                                  snapshot.data!;
                              final conditionalBuilderStatsRecord =
                                  conditionalBuilderStatsRecordList.isNotEmpty
                                      ? conditionalBuilderStatsRecordList.first
                                      : null;

                              return Builder(
                                builder: (context) {
                                  if (conditionalBuilderStatsRecord != null) {
                                    return Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      valueOrDefault<String>(
                                                        conditionalBuilderStatsRecord
                                                            .minutesToday
                                                            .toString(),
                                                        '0',
                                                      ),
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            fontFamily: 'Cool',
                                                            fontSize: 30,
                                                            letterSpacing: 0.0,
                                                          ),
                                                    ),
                                                    Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        '2dq1u1yc' /* Продолжительность звонков */,
                                                      ),
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 16,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  width: 64,
                                                  height: 64,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            26),
                                                    border: Border.all(
                                                      color: FlutterFlowTheme
                                                              .of(context)
                                                          .secondaryBackground,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    FFIcons.kclock,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                    size: 20,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      valueOrDefault<String>(
                                                        conditionalBuilderStatsRecord
                                                            .callsToday
                                                            .toString(),
                                                        '0',
                                                      ),
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            fontFamily: 'Cool',
                                                            fontSize: 30,
                                                            letterSpacing: 0.0,
                                                          ),
                                                    ),
                                                    Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        'f4nn7fxp' /* Звонков всего */,
                                                      ),
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 16,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  width: 64,
                                                  height: 64,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            26),
                                                    border: Border.all(
                                                      color: FlutterFlowTheme
                                                              .of(context)
                                                          .secondaryBackground,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    FFIcons.kphone,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                    size: 20,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ].divide(SizedBox(height: 16)),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      width: double.infinity,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Image.asset(
                                              'assets/images/Group_21.png',
                                              width: 96,
                                              height: 96,
                                              fit: BoxFit.cover,
                                              alignment: Alignment(0, -1),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(12, 0, 0, 0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      'laxcndbb' /* Звонков ещё не было */,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 16,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(
                                                                0, 6, 0, 0),
                                                    child: Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        '0hw93aax' /* Самое время это исправить.
Нач... */
                                                        ,
                                                      ),
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 14,
                                                                letterSpacing:
                                                                    0.0,
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
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ]
                        .addToStart(SizedBox(height: 55))
                        .addToEnd(SizedBox(height: 116)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardMenuOption<T> {
  const _DashboardMenuOption({
    required this.value,
    required this.label,
    this.selected = false,
  });

  final T value;
  final String label;
  final bool selected;
}
